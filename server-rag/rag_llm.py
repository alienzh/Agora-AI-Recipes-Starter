import json
import random
import logging
import uvicorn
import traceback
import asyncio
from typing import List, Union, Dict, Optional
from pydantic import BaseModel, HttpUrl

from fastapi.responses import StreamingResponse
from fastapi import FastAPI, HTTPException, Header
from openai import AsyncOpenAI

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="RAG Chat Completion API",
    description="API for RAG-enhanced streaming chat completions",
    version="1.0.0",
)

# LLM API base URL configuration
# Modify this URL to point to your LLM provider's endpoint
# Note: base_url should NOT include /chat/completions path, as AsyncOpenAI client will add it automatically
LLM_BASE_URL = "https://api.deepseek.com"  # Change this to your LLM provider's endpoint if needed

# Waiting messages for RAG requests
WAITING_MESSAGES = [
    "稍等片刻，我正在思考...",
    "让我想一下...",
    "好问题，让我查找一下相关信息...",
]

# Import knowledge base manager
try:
    from knowledge_base import get_knowledge_base
    USE_KB_MODULE = True
except ImportError:
    USE_KB_MODULE = False
    # Fallback: Empty knowledge base if module not available
    KNOWLEDGE_BASE = {}


def extract_api_key_from_header(authorization: Optional[str] = None) -> str:
    """
    Extracts API key from Authorization header.
    
    Args:
        authorization: Authorization header value (e.g., "Bearer sk-...")
    
    Returns:
        str: API key
    
    Raises:
        HTTPException: If no API key is found
    """
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="API key is required. Provide it via Authorization header (Bearer <key>)."
        )
    
    # Handle "Bearer <token>" format
    if authorization.startswith("Bearer "):
        api_key = authorization[7:].strip()
        if api_key:
            return api_key
    
    # Handle direct token (without Bearer prefix)
    if authorization.strip():
        return authorization.strip()
    
    # Invalid format
    raise HTTPException(
        status_code=401,
        detail="Invalid Authorization header format. Use 'Bearer <your-api-key>' format."
    )


def get_openai_client(api_key: str) -> AsyncOpenAI:
    """
    Creates and returns an AsyncOpenAI client instance compatible with various LLM providers.
    
    Args:
        api_key: API key for the LLM provider (from Authorization header)
    
    Returns:
        AsyncOpenAI: Configured OpenAI-compatible client instance
    """
    return AsyncOpenAI(api_key=api_key, base_url=LLM_BASE_URL)


def extract_query_from_messages(
    messages: List[Dict]
) -> str:
    """
    Extracts the query from message list (typically the last user message).
    
    Args:
        messages: List of message dictionaries
    
    Returns:
        str: Extracted query text
    """
    # Get the last user message as the query
    for message in reversed(messages):
        if isinstance(message, dict):
            role = message.get("role", "")
            content = message.get("content", "")
        else:
            role = getattr(message, "role", "")
            content = getattr(message, "content", "")
        
        if role == "user":
            if isinstance(content, str):
                return content
            elif isinstance(content, list):
                # Extract text from content list
                for item in content:
                    if isinstance(item, dict) and item.get("type") == "text":
                        return item.get("text", "")
                    elif hasattr(item, "type") and getattr(item, "type", None) == "text":
                        return getattr(item, "text", "")
                return str(content)
    
    return ""


async def perform_rag_retrieval(
    messages: List[Dict],
    knowledge_base: Dict[str, List[str]] = None
) -> str:
    """
    Retrieves relevant content from the knowledge base using RAG.
    
    Args:
        messages: Original message list
        knowledge_base: Knowledge base dictionary (optional, uses KnowledgeBase module if available)
    
    Returns:
        str: Retrieved text content
    """
    # Extract query from messages
    query = extract_query_from_messages(messages)
    
    if not query:
        return "No query found in messages."
    
    # Use KnowledgeBase module if available
    if USE_KB_MODULE:
        kb = get_knowledge_base()
        logger.info(f"🔍 RAG Retrieval: Searching knowledge base for query: '{query}'")
        retrieved_chunks = kb.search(query, top_k=3)
        logger.info(f"📚 RAG Retrieval: Found {len(retrieved_chunks)} relevant chunks")
        if retrieved_chunks:
            logger.debug(f"📄 RAG Retrieval: Retrieved chunks: {retrieved_chunks}")
            return "\n\n".join(retrieved_chunks)
        else:
            logger.warning(f"⚠️ RAG Retrieval: No relevant information found for query: '{query}'")
            return "No relevant information found in knowledge base."
    
    # Fallback: Simple keyword-based retrieval
    if knowledge_base is None:
        knowledge_base = KNOWLEDGE_BASE
    
    query_lower = query.lower()
    retrieved_chunks = []
    
    for category, docs in knowledge_base.items():
        for doc in docs:
            # Simple keyword matching (replace with semantic search)
            if any(keyword in doc.lower() for keyword in query_lower.split()):
                retrieved_chunks.append(doc)
    
    # Limit to top 3 most relevant chunks
    retrieved_chunks = retrieved_chunks[:3]
    
    if retrieved_chunks:
        return "\n\n".join(retrieved_chunks)
    else:
        # Return default knowledge if no match found, or empty string if no default
        default_docs = knowledge_base.get("default", [])
        if default_docs:
            return "\n\n".join(default_docs)
        else:
            return "No relevant information found in knowledge base."


def refact_messages(
    context: str,
    messages: List[Dict],
) -> List[Dict]:
    """
    Adjusts the message list by adding the retrieved context to the original message list.
    
    Args:
        context: Retrieved context from RAG
        messages: Original message list
    
    Returns:
        List: Adjusted message list with context prepended as system message
    """
    # Convert Pydantic models to dicts if needed
    message_dicts = []
    for msg in messages:
        if isinstance(msg, dict):
            message_dicts.append(msg)
        else:
            # Convert Pydantic model to dict
            message_dicts.append(msg.model_dump() if hasattr(msg, "model_dump") else msg.dict())
    
    # Prepend system message with context
    context_message = {
        "role": "system",
        "content": f"Use the following context to answer the user's question:\n\n{context}\n\nIf the context doesn't contain relevant information, use your general knowledge to answer."
    }
    
    return [context_message] + message_dicts


# Data models (simplified, can import from custom_llm if needed)
class TextContent(BaseModel):
    type: str = "text"
    text: str


class ImageContent(BaseModel):
    type: str = "image"
    image_url: HttpUrl


class SystemMessage(BaseModel):
    role: str = "system"
    content: Union[str, List[str]]


class UserMessage(BaseModel):
    role: str = "user"
    content: Union[str, List[Union[TextContent, ImageContent]]]


class AssistantMessage(BaseModel):
    role: str = "assistant"
    content: Union[str, List[TextContent]] = None
    tool_calls: Optional[List[Dict]] = None


class ToolMessage(BaseModel):
    role: str = "tool"
    content: Union[str, List[str]]
    tool_call_id: str


class ToolFunction(BaseModel):
    name: str
    description: Optional[str]
    parameters: Optional[Dict]
    strict: bool = False


class Tool(BaseModel):
    type: str = "function"
    function: ToolFunction


class ToolChoice(BaseModel):
    type: str = "function"
    function: Optional[Dict]


class ResponseFormat(BaseModel):
    type: str = "json_schema"
    json_schema: Optional[Dict[str, str]]


class ChatCompletionRequest(BaseModel):
    model: Optional[str] = None
    messages: List[Union[SystemMessage, UserMessage, AssistantMessage, ToolMessage]]
    response_format: Optional[ResponseFormat] = None
    tools: Optional[List[Tool]] = None
    tool_choice: Optional[Union[str, ToolChoice]] = "auto"
    parallel_tool_calls: bool = True
    stream: bool = True
    stream_options: Optional[Dict] = None


@app.post("/rag/chat/completions")
async def create_rag_chat_completion(
    request: ChatCompletionRequest,
    authorization: Optional[str] = Header(None, alias="Authorization")
):
    """
    RAG-enhanced chat completion endpoint.
    
    This endpoint:
    1. Sends a waiting message to the client
    2. Performs RAG retrieval based on user query
    3. Refactors messages with retrieved context
    4. Calls LLM with enhanced context
    5. Streams the response back to client
    """
    try:
        logger.info(f"Received RAG request: {request.model_dump_json()}")
        
        # Extract API key from Authorization header
        api_key = extract_api_key_from_header(authorization)
        
        if not request.stream:
            raise HTTPException(
                status_code=400, detail="chat completions require streaming"
            )

        async def generate():
            try:
                # First send a "please wait" prompt
                waiting_message = {
                    "id": "waiting_msg",
                    "choices": [
                        {
                            "index": 0,
                            "delta": {
                                "role": "assistant",
                                "content": random.choice(WAITING_MESSAGES),
                            },
                            "finish_reason": None,
                        }
                    ],
                }
                yield f"data: {json.dumps(waiting_message)}\n\n"

                # Perform RAG retrieval
                retrieved_context = await perform_rag_retrieval(request.messages)
                logger.info(f"✅ RAG Context Retrieved: {len(retrieved_context)} characters")

                # Adjust messages with retrieved context
                refacted_messages = refact_messages(retrieved_context, request.messages)
                logger.debug(f"📝 RAG Messages Refactored: Added context to {len(refacted_messages)} messages")

                # Request LLM completion with enhanced context
                client = get_openai_client(api_key)
                response = await client.chat.completions.create(
                    model=request.model,
                    messages=refacted_messages,
                    tool_choice=(
                        request.tool_choice
                        if request.tools and request.tool_choice
                        else None
                    ),
                    tools=request.tools if request.tools else None,
                    response_format=request.response_format,
                    stream=True,  # Force streaming
                    stream_options=request.stream_options,
                )

                async for chunk in response:
                    logger.debug(f"Received RAG chunk: {chunk}")
                    yield f"data: {json.dumps(chunk.to_dict())}\n\n"
                yield "data: [DONE]\n\n"
            except asyncio.CancelledError:
                logger.info("RAG stream was cancelled")
                raise
            except Exception as e:
                logger.error(f"Error in RAG stream generation: {str(e)}")
                raise

        return StreamingResponse(generate(), media_type="text/event-stream")

    except asyncio.CancelledError:
        logger.info("RAG request was cancelled")
        raise HTTPException(status_code=499, detail="Request was cancelled")
    except Exception as e:
        traceback_str = "".join(traceback.format_tb(e.__traceback__))
        error_message = f"{str(e)}\n{traceback_str}"
        logger.error(error_message)
        # Don't expose full traceback to client in production
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

