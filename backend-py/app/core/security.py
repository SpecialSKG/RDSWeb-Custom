"""
Dependencia de autenticación JWT para FastAPI.

Replica la lógica del middleware/authenticate.js:
  - Lee el token desde la cookie ``rdweb_token``.
  - Valida firma y expiración.
  - Devuelve el payload como ``UserPayload``.
"""

from __future__ import annotations

from fastapi import Cookie, HTTPException, status
from jose import JWTError, jwt

from app.core import config
from app.models.schemas import UserPayload


def authenticate(rdweb_token: str | None = Cookie(default=None)) -> UserPayload:
    """Dependencia inyectable en cualquier ruta protegida."""
    if not rdweb_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "No autenticado", "code": "NO_TOKEN"},
        )
    try:
        payload = jwt.decode(rdweb_token, config.JWT_SECRET, algorithms=["HS256"])
        return UserPayload(**payload)
    except JWTError as exc:
        error_str = str(exc)
        if "expired" in error_str.lower():
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={"error": "Sesión expirada", "code": "TOKEN_EXPIRED"},
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "Token inválido", "code": "INVALID_TOKEN"},
        ) from exc
