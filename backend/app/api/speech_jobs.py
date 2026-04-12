from fastapi import APIRouter, BackgroundTasks, Depends

from app.core.exceptions import ApiException
from app.core.security import get_current_user_id
from app.schemas.speech_jobs import (
    CreateSpeechJobRequest,
    CreateSpeechJobResponse,
    SpeechJobResponse,
    SummarizationStartedResponse,
    SummarizeSpeechJobRequest,
)
from app.services.job_service import JobService, get_job_service

router = APIRouter(prefix="/speech-jobs", tags=["speech-jobs"])


@router.post("", response_model=CreateSpeechJobResponse, status_code=201)
async def create_speech_job(
    payload: CreateSpeechJobRequest,
    user_id: str = Depends(get_current_user_id),
    service: JobService = Depends(get_job_service),
) -> CreateSpeechJobResponse:
    data = service.create_job(
        user_id=user_id,
        audio_file_size=payload.audio_file_size,
        duration_seconds=payload.duration_seconds,
        tournament_id=payload.tournament_id,
    )
    return CreateSpeechJobResponse.model_validate(data)


@router.get("/{job_id}", response_model=SpeechJobResponse)
async def get_speech_job(
    job_id: str,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user_id),
    service: JobService = Depends(get_job_service),
) -> SpeechJobResponse:
    data = service.get_job_for_user(user_id=user_id, job_id=job_id)

    # Start transcription after upload has been detected; work runs in background.
    if data["status"] == "uploaded":
        try:
            if service.can_start_transcription(user_id=user_id, job_id=job_id):
                service.mark_transcribing(user_id=user_id, job_id=job_id)
                background_tasks.add_task(service.run_transcription, job_id, user_id)
                data = service.get_job_for_user(user_id=user_id, job_id=job_id)
        except ApiException:
            raise

    return SpeechJobResponse.model_validate(data)


@router.post("/{job_id}/summarize", response_model=SummarizationStartedResponse, status_code=202)
async def summarize_speech_job(
    job_id: str,
    request: SummarizeSpeechJobRequest,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user_id),
    service: JobService = Depends(get_job_service),
) -> SummarizationStartedResponse:
    max_length = request.settings.max_length if request.settings else None
    data = service.request_summarization(user_id=user_id, job_id=job_id, requested_max_length=max_length)
    background_tasks.add_task(service.run_summarization, job_id, user_id, data["effectiveMaxLength"])
    return SummarizationStartedResponse.model_validate(
        {
            "jobId": data["jobId"],
            "status": data["status"],
            "message": data["message"],
        }
    )
