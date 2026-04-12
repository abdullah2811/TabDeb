from datetime import datetime, timedelta, timezone
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore, storage

from app.core.config import get_settings
from app.core.exceptions import ApiException


class FirebaseService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self._initialize_admin_app()
        self.db = firestore.client()
        self.bucket = storage.bucket(self.settings.firebase_storage_bucket)

    def _initialize_admin_app(self) -> None:
        if firebase_admin._apps:
            return

        cred_path = self.settings.google_application_credentials
        if cred_path:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(
                cred,
                {
                    "projectId": self.settings.firebase_project_id,
                    "storageBucket": self.settings.firebase_storage_bucket,
                },
            )
            return

        # Fallback to application default credentials.
        firebase_admin.initialize_app(
            options={
                "projectId": self.settings.firebase_project_id,
                "storageBucket": self.settings.firebase_storage_bucket,
            }
        )

    @staticmethod
    def now_utc() -> datetime:
        return datetime.now(timezone.utc)

    def speech_job_doc_ref(self, job_id: str):
        return self.db.collection("speech_jobs").document(job_id)

    def user_speech_job_doc_ref(self, user_id: str, job_id: str):
        return (
            self.db.collection("users")
            .document(user_id)
            .collection("speech_jobs")
            .document(job_id)
        )

    def write_job(self, job_payload: dict[str, Any]) -> None:
        job_id = str(job_payload["id"])
        user_id = str(job_payload["userId"])
        batch = self.db.batch()
        batch.set(self.speech_job_doc_ref(job_id), job_payload)
        batch.set(self.user_speech_job_doc_ref(user_id, job_id), job_payload)
        batch.commit()

    def update_job(self, user_id: str, job_id: str, partial_payload: dict[str, Any]) -> None:
        payload = dict(partial_payload)
        payload["updatedAt"] = self.now_utc()

        batch = self.db.batch()
        batch.update(self.speech_job_doc_ref(job_id), payload)
        batch.update(self.user_speech_job_doc_ref(user_id, job_id), payload)
        batch.commit()

    def get_job(self, job_id: str) -> dict[str, Any] | None:
        doc = self.speech_job_doc_ref(job_id).get()
        if not doc.exists:
            return None
        return doc.to_dict()

    def get_job_for_user(self, user_id: str, job_id: str) -> dict[str, Any]:
        payload = self.get_job(job_id)
        if payload is None:
            raise ApiException(
                error="job_not_found",
                message=f"Job with ID '{job_id}' does not exist",
                status_code=404,
            )

        if payload.get("userId") != user_id:
            raise ApiException(
                error="forbidden",
                message="You do not have permission to access this job",
                status_code=403,
            )
        return payload

    def build_audio_storage_path(self, user_id: str, job_id: str) -> str:
        return f"speech_audio/{user_id}/{job_id}.m4a"

    def generate_audio_upload_url(self, audio_storage_path: str) -> str:
        blob = self.bucket.blob(audio_storage_path)
        expiry = timedelta(seconds=self.settings.signed_url_expiry_seconds)
        try:
            return blob.generate_signed_url(
                version="v4",
                expiration=expiry,
                method="PUT",
                content_type="audio/m4a",
            )
        except Exception as exc:
            raise ApiException(
                error="internal_error",
                message=(
                    "Failed to generate signed upload URL. Ensure backend uses a "
                    "service account with signing permissions."
                ),
                status_code=500,
            ) from exc

    def audio_blob_exists(self, audio_storage_path: str) -> bool:
        blob = self.bucket.blob(audio_storage_path)
        return blob.exists()

    def download_audio_bytes(self, audio_storage_path: str) -> bytes:
        blob = self.bucket.blob(audio_storage_path)
        if not blob.exists():
            raise ApiException(
                error="invalid_state",
                message="Audio file has not been uploaded yet",
                status_code=409,
            )
        return blob.download_as_bytes()
