from datetime import datetime, timezone


class ApiException(Exception):
    def __init__(self, error: str, message: str, status_code: int) -> None:
        super().__init__(message)
        self.error = error
        self.message = message
        self.status_code = status_code

    def to_response(self) -> dict:
        return {
            "error": self.error,
            "message": self.message,
            "statusCode": self.status_code,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
