import base64
import json
from openai import AsyncOpenAI
import traceback
import logging
import uvicorn
import aiofiles
import uuid
from typing import List, Union, Dict, Optional
from pydantic import BaseModel, HttpUrl

from fastapi.responses import StreamingResponse
from fastapi import FastAPI, HTTPException, Header
import asyncio
import random

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Chat Completion API",
    description="API for streaming chat completions with support for text, image, and audio content",
    version="1.0.0",
)

# LLM API base URL configuration
# Modify this URL to point to your LLM provider's endpoint
# Default: OpenAI API endpoint
LLM_BASE_URL = "https://api.chatanywhere.tech"  # Change this to your LLM provider's endpoint if needed


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


class AudioContent(BaseModel):
    type: str = "input_audio"
    input_audio: Dict[str, str]


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
    content: Union[str, List[Union[TextContent, ImageContent, AudioContent]]]


class AssistantMessage(BaseModel):
    role: str = "assistant"
    content: Union[str, List[TextContent]] = None
    audio: Optional[Dict[str, str]] = None
    tool_calls: Optional[List[Dict]] = None


class ToolMessage(BaseModel):
    role: str = "tool"
    content: Union[str, List[str]]
    tool_call_id: str


class ChatCompletionRequest(BaseModel):
    context: Optional[Dict] = None
    model: Optional[str] = None
    messages: List[Union[SystemMessage, UserMessage, AssistantMessage, ToolMessage]]
    response_format: Optional[ResponseFormat] = None
    modalities: List[str] = ["text"]
    audio: Optional[Dict[str, str]] = None
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
                    modalities=request.modalities,
                    audio=request.audio,
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


async def perform_rag_retrieval(
    messages: List[Union[SystemMessage, UserMessage, AssistantMessage, ToolMessage]]
) -> str:
    """
    Retrieves relevant content from the knowledge base message list using the RAG model.
    
    Args:
        messages: Original message list
    
    Returns:
        str: Retrieved text content
    """
    # TODO: Implement actual RAG retrieval logic
    # You may need to take the first or the last message from the messages as the query, depending on your specific needs
    # Then send the query to the RAG model to retrieve relevant content
    
    # Return retrieval results
    return "This is relevant content retrieved from the knowledge base."


def refact_messages(
    context: str,
    messages: List[Union[SystemMessage, UserMessage, AssistantMessage, ToolMessage]],
) -> List[Union[SystemMessage, UserMessage, AssistantMessage, ToolMessage]]:
    """
    Adjusts the message list by adding the retrieved context to the original message list.
    
    Args:
        context: Retrieved context
        messages: Original message list
    
    Returns:
        List: Adjusted message list
    """
    # TODO: Implement actual message adjustment logic
    # This should add the retrieved context to the original message list
    # For example, you could prepend a system message with the context:
    # system_message = SystemMessage(role="system", content=f"Context: {context}")
    # return [system_message] + messages
    
    # For now, just return the original messages
    return messages


waiting_messages = [
    "Just a moment, I'm thinking...",
    "Let me think about that for a second...",
    "Good question, let me find out...",
]


@app.post("/rag/chat/completions")
async def create_rag_chat_completion(
    request: ChatCompletionRequest,
    authorization: Optional[str] = Header(None, alias="Authorization")
):
    try:
        logger.info(f"Received RAG request: {request.model_dump_json()}")
        
        # Extract API key from Authorization header or environment variable
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
                                "content": random.choice(waiting_messages),
                            },
                            "finish_reason": None,
                        }
                    ],
                }
                yield f"data: {json.dumps(waiting_message)}\n\n"

                # Perform RAG retrieval
                retrieved_context = await perform_rag_retrieval(request.messages)

                # Adjust messages
                refacted_messages = refact_messages(retrieved_context, request.messages)

                # Request LLM completion
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
                    modalities=request.modalities,
                    audio=request.audio,
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


async def read_text_file(file_path: str) -> str:
    """
    Reads a text file and returns the content

    Args:
        file_path: Path to the text file

    Returns:
        str: Content of the text file

    """
    async with aiofiles.open(file_path, "r") as file:
        content = await file.read()

    return content


async def read_pcm_file(
    file_path: str, sample_rate: int, duration_ms: int
) -> List[bytes]:
    """
    Reads a PCM file and returns a list of audio chunks

    Args:
        file_path: Path to the PCM file
        sample_rate: Sample rate of the audio
        duration_ms: Duration of each audio chunk in milliseconds

    Returns:
        List: List of audio chunks

    """

    async with aiofiles.open(file_path, "rb") as file:
        content = await file.read()

    chunk_size = int(sample_rate * 2 * (duration_ms / 1000))
    return [content[i : i + chunk_size] for i in range(0, len(content), chunk_size)]


@app.post("/audio/chat/completions")
async def create_audio_chat_completion(
    request: ChatCompletionRequest,
    authorization: Optional[str] = Header(None, alias="Authorization")
):
    try:
        logger.info(f"Received audio request: {request.model_dump_json()}")
        
        # Extract API key from Authorization header or environment variable
        # Note: Audio endpoint doesn't use LLM API, but we validate for consistency
        api_key = extract_api_key_from_header(authorization)

        if not request.stream:
            raise HTTPException(
                status_code=400, detail="chat completions require streaming"
            )

        # Example usage of reading text and audio files
        # Replace with your own logic

        text_file_path = "./file.txt"
        pcm_file_path = "./file.pcm"
        sample_rate = 16000  # Example sample rate
        duration_ms = 40  # 40ms chunks

        text_content = await read_text_file(text_file_path)
        audio_chunks = await read_pcm_file(pcm_file_path, sample_rate, duration_ms)

        async def generate():
            try:
                # Send text content
                audio_id = uuid.uuid4().hex
                text_message = {
                    "id": uuid.uuid4().hex,
                    "choices": [
                        {
                            "index": 0,
                            "delta": {
                                "audio": {
                                    "id": audio_id,
                                    "transcript": text_content,
                                },
                            },
                            "finish_reason": None,
                        }
                    ],
                }
                yield f"data: {json.dumps(text_message)}\n\n"

                # Send audio chunks
                for chunk in audio_chunks:
                    audio_message = {
                        "id": uuid.uuid4().hex,
                        "choices": [
                            {
                                "index": 0,
                                "delta": {
                                    "audio": {
                                        "id": audio_id,
                                        "data": base64.b64encode(chunk).decode("utf-8"),
                                    },
                                },
                                "finish_reason": None,
                            }
                        ],
                    }
                    yield f"data: {json.dumps(audio_message)}\n\n"

                yield "data: [DONE]\n\n"

            except asyncio.CancelledError:
                logger.info("Audio stream was cancelled")
                raise

        return StreamingResponse(generate(), media_type="text/event-stream")

    except asyncio.CancelledError:
        logger.info("Audio request was cancelled")
        raise HTTPException(status_code=499, detail="Request was cancelled")
    except Exception as e:
        traceback_str = "".join(traceback.format_tb(e.__traceback__))
        error_message = f"{str(e)}\n{traceback_str}"
        logger.error(error_message)
        # Don't expose full traceback to client in production
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
