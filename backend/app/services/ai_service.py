import io

from groq import Groq
from openai import OpenAI

from app.core.config import get_settings
from app.core.exceptions import ApiException


class AIService:
    def __init__(self) -> None:
        settings = get_settings()
        self.settings = settings
        self._openai = OpenAI(api_key=settings.openai_api_key)
        self._groq = Groq(api_key=settings.groq_api_key)

    def transcribe_audio_bytes(self, audio_bytes: bytes, filename: str = "speech.m4a") -> str:
        try:
            file_buffer = io.BytesIO(audio_bytes)
            file_buffer.name = filename
            response = self._openai.audio.transcriptions.create(
                model=self.settings.whisper_model,
                file=file_buffer,
                response_format="text",
            )
            text = str(response).strip()
            if not text:
                raise ApiException(
                    error="internal_error",
                    message="Whisper returned an empty transcription",
                    status_code=500,
                )
            return text
        except ApiException:
            raise
        except Exception as exc:
            raise ApiException(
                error="internal_error",
                message="Audio transcription service temporarily unavailable",
                status_code=500,
            ) from exc

    def summarize_text(self, transcript: str, max_length: int) -> str:
        prompt = (
            "You are an assistant that summarizes debate speeches. "
            "Return a clear summary in plain text. "
            f"Target length: up to {max_length} words.\n\n"
            "Transcript:\n"
            f"{transcript}"
        )

        try:
            response = self._groq.chat.completions.create(
                model=self.settings.groq_model,
                messages=[
                    {
                        "role": "system",
                        "content": "Summarize accurately, avoid hallucinations, and preserve key arguments.",
                    },
                    {"role": "user", "content": prompt},
                ],
                temperature=0.2,
            )
            content = response.choices[0].message.content if response.choices else None
            summary = (content or "").strip()
            if not summary:
                raise ApiException(
                    error="internal_error",
                    message="Summarization provider returned an empty response",
                    status_code=500,
                )
            return summary
        except ApiException:
            raise
        except Exception as exc:
            raise ApiException(
                error="internal_error",
                message="Summarization service temporarily unavailable",
                status_code=500,
            ) from exc
