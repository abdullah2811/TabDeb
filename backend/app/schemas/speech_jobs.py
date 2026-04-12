from datetime import datetime
from enum import Enum
from pydantic import BaseModel, ConfigDict, Field


class SpeechJobStatus(str, Enum):
    uploaded = "uploaded"
    transcribing = "transcribing"
    transcribed = "transcribed"
    summarizing = "summarizing"
    completed = "completed"
    failed = "failed"


class CreateSpeechJobRequest(BaseModel):
    audio_file_size: int = Field(alias="audioFileSize", gt=0)
    duration_seconds: int | None = Field(default=None, alias="durationSeconds", ge=0)
    tournament_id: str | None = Field(default=None, alias="tournamentId")

    model_config = ConfigDict(populate_by_name=True)


class CreateSpeechJobResponse(BaseModel):
    job_id: str = Field(alias="jobId")
    status: SpeechJobStatus
    upload_url: str = Field(alias="uploadUrl")
    audio_storage_path: str = Field(alias="audioStoragePath")
    created_at: datetime = Field(alias="createdAt")
    expires_in: int = Field(alias="expiresIn")

    model_config = ConfigDict(populate_by_name=True)


class SpeechJobResponse(BaseModel):
    job_id: str = Field(alias="jobId")
    status: SpeechJobStatus
    user_id: str = Field(alias="userId")
    duration_seconds: int | None = Field(default=None, alias="durationSeconds")
    transcript: str | None = None
    summary: str | None = None
    error: str | None = None
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")
    completed_at: datetime | None = Field(default=None, alias="completedAt")

    model_config = ConfigDict(populate_by_name=True)


class SummarizationSettings(BaseModel):
    max_length: int | None = Field(default=None, alias="maxLength", ge=1)

    model_config = ConfigDict(populate_by_name=True)


class SummarizeSpeechJobRequest(BaseModel):
    settings: SummarizationSettings | None = None


class SummarizationStartedResponse(BaseModel):
    job_id: str = Field(alias="jobId")
    status: SpeechJobStatus
    message: str

    model_config = ConfigDict(populate_by_name=True)


class ErrorResponse(BaseModel):
    error: str
    message: str
    status_code: int = Field(alias="statusCode")
    timestamp: str

    model_config = ConfigDict(populate_by_name=True)
