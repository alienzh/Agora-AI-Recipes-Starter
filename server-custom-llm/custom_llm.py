import json
from openai import AsyncOpenAI
import traceback
import logging
import uvicorn
from typing import List, Union, Dict, Optional
from pydantic import BaseModel, HttpUrl

from fastapi.responses import StreamingResponse
from fastapi import FastAPI, HTTPException, Header
import asyncio

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Chat Completion API",
    description="API for streaming chat completions with support for text and image content",
    version="1.0.0",
)

# LLM API base URL configuration
# Modify this URL to point to your LLM provider's endpoint
# Default: OpenAI API endpoint
# Note: base_url should NOT include /chat/completions path, as AsyncOpenAI client will add it automatically
LLM_BASE_URL = "https://api.deepseek.com"  # Change this to your LLM provider's endpoint if needed


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
    
    Note:
        Modify LLM_BASE_URL constant above to change the API endpoint.
    """
    return AsyncOpenAI(api_key=api_key, base_url=LLM_BASE_URL)


class TextContent(BaseModel):
    type: str = "text"
    text: str


class ImageContent(BaseModel):
    type: str = "image"
    image_url: HttpUrl


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


class ChatCompletionRequest(BaseModel):
    model: Optional[str] = None
    messages: List[Union[SystemMessage, UserMessage, AssistantMessage, ToolMessage]]
    response_format: Optional[ResponseFormat] = None
    tools: Optional[List[Tool]] = None
    tool_choice: Optional[Union[str, ToolChoice]] = "auto"
    parallel_tool_calls: bool = True
    stream: bool = True
    stream_options: Optional[Dict] = None


@app.post("/chat/completions")
async def create_chat_completion(
    request: ChatCompletionRequest,
    authorization: Optional[str] = Header(None, alias="Authorization")
):
    try:
        logger.info(f"Received request: {request.model_dump_json()}")
        
        # Extract API key from Authorization header or environment variable
        api_key = extract_api_key_from_header(authorization)
        
        if not request.stream:
            raise HTTPException(
                status_code=400, detail="chat completions require streaming"
            )

        async def generate():
            try:
                client = get_openai_client(api_key)
                response = await client.chat.completions.create(
                    model=request.model,
                    messages=request.messages,  # Directly use request messages
                    tool_choice=(
                        request.tool_choice if request.tools and request.tool_choice else None
                    ),
                    tools=request.tools if request.tools else None,
                    response_format=request.response_format,
                    stream=request.stream,
                    stream_options=request.stream_options,
                )
                async for chunk in response:
                    logger.debug(f"Received chunk: {chunk}")
                    yield f"data: {json.dumps(chunk.to_dict())}\n\n"
                yield "data: [DONE]\n\n"
            except asyncio.CancelledError:
                logger.info("Request was cancelled")
                raise

        return StreamingResponse(generate(), media_type="text/event-stream")
    except asyncio.CancelledError:
        logger.info("Request was cancelled")
        raise HTTPException(status_code=499, detail="Request was cancelled")
    except Exception as e:
        traceback_str = "".join(traceback.format_tb(e.__traceback__))
        error_message = f"{str(e)}\n{traceback_str}"
        logger.error(error_message)
        # Don't expose full traceback to client in production
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
