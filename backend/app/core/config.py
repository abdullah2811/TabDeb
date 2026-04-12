from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Speech Pipeline API"
    api_prefix: str = "/v1"
    environment: str = "development"

    # Firebase
    firebase_project_id: str
    firebase_storage_bucket: str
    google_application_credentials: str | None = None

    # AI providers (kept only on backend)
    openai_api_key: str
    groq_api_key: str
    whisper_model: str = "whisper-1"
    groq_model: str = "llama-3.1-8b-instant"

    # Upload and processing limits
    max_audio_size_bytes: int = 50 * 1024 * 1024
    signed_url_expiry_seconds: int = 3600
    default_summary_max_length: int = 200
    max_summary_max_length: int = 1000

    # CORS
    allowed_origins: str = "*"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @property
    def allowed_origins_list(self) -> list[str]:
        value = self.allowed_origins.strip()
        if not value:
            return ["*"]
        return [origin.strip() for origin in value.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
