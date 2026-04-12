from fastapi import Header
import firebase_admin.auth

from app.core.exceptions import ApiException


async def get_current_user_id(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise ApiException(
            error="invalid_token",
            message="Missing or invalid Authorization header",
            status_code=401,
        )

    id_token = authorization.split("Bearer ", maxsplit=1)[1].strip()
    if not id_token:
        raise ApiException(
            error="invalid_token",
            message="Firebase token is missing",
            status_code=401,
        )

    try:
        decoded = firebase_admin.auth.verify_id_token(id_token)
        user_id = decoded.get("uid")
        if not user_id:
            raise ApiException(
                error="invalid_token",
                message="Token payload does not include user identity",
                status_code=401,
            )
        return str(user_id)
    except ApiException:
        raise
    except Exception:
        raise ApiException(
            error="invalid_token",
            message="Firebase token is invalid or expired",
            status_code=401,
        )
