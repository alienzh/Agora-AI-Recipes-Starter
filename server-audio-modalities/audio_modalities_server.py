import json
import traceback
import logging
import uvicorn
from typing import List, Union, Dict, Optional
from pydantic import BaseModel

from fastapi.responses import StreamingResponse
from fastapi import FastAPI, HTTPException, Header
import asyncio

from audio_modalities import create_audio_chat_completion_handler

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Audio Modalities API",
    description="API for streaming audio chat completions with support for text transcript and audio chunks",
    version="1.0.0",
)


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


class TextContent(BaseModel):
    type: str = "text"
    text: str


class ImageContent(BaseModel):
    type: str = "image"
    image_url: str


class AudioContent(BaseModel):
    type: str = "input_audio"
    input_audio: Dict[str, str]


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
    model: Optional[str] = None
    messages: List[Union[SystemMessage, UserMessage, AssistantMessage, ToolMessage]]
    modalities: List[str] = ["text", "audio"]
    audio: Optional[Dict[str, str]] = None
    stream: bool = True
    stream_options: Optional[Dict] = None


@app.post("/audio/chat/completions")
async def create_audio_chat_completion(
    request: ChatCompletionRequest,
    authorization: Optional[str] = Header(None, alias="Authorization")
):
    """
    Audio chat completion endpoint that returns streaming audio responses.
    
    This endpoint simulates audio responses by reading text and audio files,
    then streaming them back as SSE (Server-Sent Events) format.
    
    Args:
        request: Chat completion request with messages and audio configuration
        authorization: Authorization header containing API key
    
    Returns:
        StreamingResponse: SSE formatted response with audio transcript and chunks
    """
    try:
        logger.info(f"Received audio request: {request.model_dump_json()}")
        
        # Extract API key from Authorization header
        # Note: Audio endpoint doesn't use LLM API, but we validate for consistency
        api_key = extract_api_key_from_header(authorization)
        
        return await create_audio_chat_completion_handler(request, api_key)

    except asyncio.CancelledError:
        logger.info("Audio request was cancelled")
        raise HTTPException(status_code=499, detail="Request was cancelled")
    except Exception as e:
        traceback_str = "".join(traceback.format_tb(e.__traceback__))
        error_message = f"{str(e)}\n{traceback_str}"
        logger.error(error_message)
        # Don't expose full traceback to client in production
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "ok"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)

