from datetime import datetime, timezone
from functools import lru_cache
from typing import Any
from uuid import uuid4

from google.cloud import firestore

from app.core.config import get_settings
from app.core.exceptions import ApiException
from app.schemas.speech_jobs import SpeechJobStatus
from app.services.ai_service import AIService
from app.services.firebase_service import FirebaseService


class JobService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.firebase = FirebaseService()
        self.ai = AIService()

    @staticmethod
    def _now() -> datetime:
        return datetime.now(timezone.utc)

    def create_job(self, user_id: str, audio_file_size: int, duration_seconds: int | None, tournament_id: str | None) -> dict[str, Any]:
        if audio_file_size <= 0:
            raise ApiException(
                error="invalid_request",
                message="audioFileSize must be positive integer",
                status_code=400,
            )

        if audio_file_size > self.settings.max_audio_size_bytes:
            raise ApiException(
                error="invalid_request",
                message=f"audioFileSize exceeds maximum allowed size ({self.settings.max_audio_size_bytes} bytes)",
                status_code=400,
            )

        now = self._now()
        job_id = f"job_{uuid4().hex}"
        audio_storage_path = self.firebase.build_audio_storage_path(user_id, job_id)

        payload = {
            "id": job_id,
            "userId": user_id,
            "tournamentId": tournament_id,
            "status": SpeechJobStatus.uploaded.value,
            "durationSeconds": duration_seconds,
            "transcript": None,
            "summary": None,
            "error": None,
            "audioStoragePath": audio_storage_path,
            "createdAt": now,
            "updatedAt": now,
            "completedAt": None,
        }
        self.firebase.write_job(payload)

        upload_url = self.firebase.generate_audio_upload_url(audio_storage_path)

        return {
            "jobId": job_id,
            "status": SpeechJobStatus.uploaded.value,
            "uploadUrl": upload_url,
            "audioStoragePath": audio_storage_path,
            "createdAt": now,
            "expiresIn": self.settings.signed_url_expiry_seconds,
        }

    def get_job_for_user(self, user_id: str, job_id: str) -> dict[str, Any]:
        payload = self.firebase.get_job_for_user(user_id=user_id, job_id=job_id)
        return self._to_api_payload(payload)

    def request_summarization(self, user_id: str, job_id: str, requested_max_length: int | None) -> dict[str, Any]:
        max_length = requested_max_length or self.settings.default_summary_max_length
        max_length = min(max_length, self.settings.max_summary_max_length)

        @firestore.transactional
        def transaction_op(transaction: firestore.Transaction):
            doc_ref = self.firebase.speech_job_doc_ref(job_id)
            snapshot = doc_ref.get(transaction=transaction)
            if not snapshot.exists:
                raise ApiException(
                    error="job_not_found",
                    message=f"Job with ID '{job_id}' does not exist",
                    status_code=404,
                )
            payload = snapshot.to_dict() or {}

            if payload.get("userId") != user_id:
                raise ApiException(
                    error="forbidden",
                    message="You do not have permission to access this job",
                    status_code=403,
                )

            status = payload.get("status")
            if status != SpeechJobStatus.transcribed.value:
                raise ApiException(
                    error="invalid_state",
                    message=f"Cannot summarize job in status '{status}'; must be 'transcribed'",
                    status_code=409,
                )

            now = self._now()
            updates = {
                "status": SpeechJobStatus.summarizing.value,
                "updatedAt": now,
                "error": None,
            }
            transaction.update(doc_ref, updates)
            user_doc_ref = self.firebase.user_speech_job_doc_ref(user_id, job_id)
            transaction.update(user_doc_ref, updates)

        transaction = self.firebase.db.transaction()
        transaction_op(transaction)
        return {
            "jobId": job_id,
            "status": SpeechJobStatus.summarizing.value,
            "message": "Summarization started",
            "effectiveMaxLength": max_length,
        }

    def can_start_transcription(self, job_id: str, user_id: str) -> bool:
        payload = self.firebase.get_job_for_user(user_id=user_id, job_id=job_id)
        if payload.get("status") != SpeechJobStatus.uploaded.value:
            return False

        audio_storage_path = str(payload.get("audioStoragePath") or "")
        if not audio_storage_path:
            return False

        return self.firebase.audio_blob_exists(audio_storage_path)

    def mark_transcribing(self, job_id: str, user_id: str) -> None:
        @firestore.transactional
        def transaction_op(transaction: firestore.Transaction):
            doc_ref = self.firebase.speech_job_doc_ref(job_id)
            snapshot = doc_ref.get(transaction=transaction)
            if not snapshot.exists:
                return

            payload = snapshot.to_dict() or {}
            if payload.get("userId") != user_id:
                return
            if payload.get("status") != SpeechJobStatus.uploaded.value:
                return

            now = self._now()
            updates = {
                "status": SpeechJobStatus.transcribing.value,
                "updatedAt": now,
                "error": None,
            }
            transaction.update(doc_ref, updates)
            transaction.update(self.firebase.user_speech_job_doc_ref(user_id, job_id), updates)

        transaction = self.firebase.db.transaction()
        transaction_op(transaction)

    def run_transcription(self, job_id: str, user_id: str) -> None:
        try:
            payload = self.firebase.get_job_for_user(user_id, job_id)
            if payload.get("status") != SpeechJobStatus.transcribing.value:
                # Another worker/request already advanced this job.
                return

            audio_storage_path = str(payload.get("audioStoragePath") or "")
            if not audio_storage_path:
                raise ApiException(
                    error="invalid_state",
                    message="Job does not contain an audio storage path",
                    status_code=409,
                )

            audio_bytes = self.firebase.download_audio_bytes(audio_storage_path)
            transcript = self.ai.transcribe_audio_bytes(audio_bytes=audio_bytes)
            now = self._now()
            self.firebase.update_job(
                user_id=user_id,
                job_id=job_id,
                partial_payload={
                    "status": SpeechJobStatus.transcribed.value,
                    "transcript": transcript,
                    "error": None,
                    "updatedAt": now,
                },
            )
        except ApiException as exc:
            self._mark_failed(job_id=job_id, user_id=user_id, message=exc.message)
        except Exception:
            self._mark_failed(
                job_id=job_id,
                user_id=user_id,
                message="Audio transcription service temporarily unavailable",
            )

    def run_summarization(self, job_id: str, user_id: str, max_length: int) -> None:
        try:
            payload = self.firebase.get_job_for_user(user_id, job_id)
            if payload.get("status") != SpeechJobStatus.summarizing.value:
                # Another worker/request already advanced this job.
                return

            transcript = str(payload.get("transcript") or "").strip()
            if not transcript:
                raise ApiException(
                    error="invalid_state",
                    message="Cannot summarize without transcript text",
                    status_code=409,
                )

            summary = self.ai.summarize_text(transcript=transcript, max_length=max_length)
            now = self._now()
            self.firebase.update_job(
                user_id=user_id,
                job_id=job_id,
                partial_payload={
                    "status": SpeechJobStatus.completed.value,
                    "summary": summary,
                    "error": None,
                    "completedAt": now,
                    "updatedAt": now,
                },
            )
        except ApiException as exc:
            self._mark_failed(job_id=job_id, user_id=user_id, message=exc.message)
        except Exception:
            self._mark_failed(
                job_id=job_id,
                user_id=user_id,
                message="Summarization service temporarily unavailable",
            )

    def _mark_failed(self, job_id: str, user_id: str, message: str) -> None:
        now = self._now()
        self.firebase.update_job(
            user_id=user_id,
            job_id=job_id,
            partial_payload={
                "status": SpeechJobStatus.failed.value,
                "error": message,
                "completedAt": now,
                "updatedAt": now,
            },
        )

    def _to_api_payload(self, payload: dict[str, Any]) -> dict[str, Any]:
        return {
            "jobId": payload.get("id", ""),
            "status": payload.get("status", SpeechJobStatus.uploaded.value),
            "userId": payload.get("userId", ""),
            "durationSeconds": payload.get("durationSeconds"),
            "transcript": payload.get("transcript"),
            "summary": payload.get("summary"),
            "error": payload.get("error"),
            "createdAt": payload.get("createdAt"),
            "updatedAt": payload.get("updatedAt"),
            "completedAt": payload.get("completedAt"),
        }


@lru_cache
def get_job_service() -> JobService:
    return JobService()
