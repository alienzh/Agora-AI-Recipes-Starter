import base64
import json
import uuid
import logging
import asyncio
from typing import List

import aiofiles
from fastapi.responses import StreamingResponse
from fastapi import HTTPException

logger = logging.getLogger(__name__)


async def read_text_file(file_path: str) -> str:
    """
    Reads a text file and returns the content

    Args:
        file_path: Path to the text file

    Returns:
        str: Content of the text file
    
    Raises:
        FileNotFoundError: If the file doesn't exist
        IOError: If there's an error reading the file
    """
    try:
        async with aiofiles.open(file_path, "r", encoding="utf-8") as file:
            content = await file.read()
        return content
    except FileNotFoundError:
        logger.error(f"Text file not found: {file_path}")
        raise HTTPException(
            status_code=404,
            detail=f"Text file not found: {file_path}. Please ensure the file exists."
        )
    except Exception as e:
        logger.error(f"Error reading text file {file_path}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error reading text file: {str(e)}"
        )


async def read_pcm_file(
    file_path: str, sample_rate: int, duration_ms: int
) -> List[bytes]:
    """
    Reads a PCM file and returns a list of audio chunks

    Args:
        file_path: Path to the PCM file
        sample_rate: Sample rate of the audio (e.g., 16000 for 16kHz)
        duration_ms: Duration of each audio chunk in milliseconds (e.g., 40 for 40ms chunks)

    Returns:
        List[bytes]: List of audio chunks
    
    Raises:
        FileNotFoundError: If the file doesn't exist
        IOError: If there's an error reading the file
    """
    try:
        async with aiofiles.open(file_path, "rb") as file:
            content = await file.read()

        # Calculate chunk size: sample_rate * bytes_per_sample * (duration_ms / 1000)
        # For PCM16: 2 bytes per sample (16-bit)
        chunk_size = int(sample_rate * 2 * (duration_ms / 1000))
        
        # Split content into chunks
        chunks = [content[i : i + chunk_size] for i in range(0, len(content), chunk_size)]
        
        return chunks
    except FileNotFoundError:
        logger.error(f"Audio file not found: {file_path}")
        raise HTTPException(
            status_code=404,
            detail=f"Audio file not found: {file_path}. Please ensure the file exists."
        )
    except Exception as e:
        logger.error(f"Error reading audio file {file_path}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error reading audio file: {str(e)}"
        )


async def create_audio_chat_completion_handler(
    request,
    api_key: str,
):
    """
    Handles audio chat completion request.
    
    This function reads text and audio files, then streams them back as SSE format.
    The response includes:
    1. A text transcript message with audio ID
    2. Multiple audio chunk messages with base64-encoded PCM data
    
    Args:
        request: Chat completion request (must have stream=True)
        api_key: API key (validated but not used for LLM API)
    
    Returns:
        StreamingResponse: SSE formatted audio response
    
    Raises:
        HTTPException: If stream is False or files are not found
    """
    if not request.stream:
        raise HTTPException(
            status_code=400, detail="chat completions require streaming"
        )

    # Configuration: File paths and audio parameters
    # Note: This is a demo implementation using fixed files.
    # In production, you can replace this with TTS services, database queries, etc.
    text_file_path = "./file.txt"
    pcm_file_path = "./file.pcm"
    sample_rate = 16000  # 16kHz sample rate
    duration_ms = 40  # 40ms chunks (typical for real-time audio streaming)

    # Read text transcript and audio file
    text_content = await read_text_file(text_file_path)
    audio_chunks = await read_pcm_file(pcm_file_path, sample_rate, duration_ms)

    async def generate():
        try:
            # Generate unique IDs for this audio response
            audio_id = uuid.uuid4().hex
            message_id = uuid.uuid4().hex
            
            # Step 1: Send text transcript message
            # This message contains the audio ID and transcript text
            text_message = {
                "id": message_id,
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
            yield f"data: {json.dumps(text_message, ensure_ascii=False)}\n\n"

            # Step 2: Send audio chunks
            # Each chunk is base64-encoded PCM audio data
            for chunk in audio_chunks:
                audio_message = {
                    "id": message_id,
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
                
                # Optional: Add small delay between chunks to simulate real-time streaming
                # await asyncio.sleep(0.04)  # 40ms delay

            # Step 3: Send completion signal
            yield "data: [DONE]\n\n"

        except asyncio.CancelledError:
            logger.info("Audio stream was cancelled")
            raise
        except Exception as e:
            logger.error(f"Error generating audio stream: {str(e)}")
            error_message = {
                "error": {
                    "message": str(e),
                    "type": "server_error"
                }
            }
            yield f"data: {json.dumps(error_message)}\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")

