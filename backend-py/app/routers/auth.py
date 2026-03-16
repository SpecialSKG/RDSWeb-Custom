"""
Router de autenticación — /api/auth

Replica exactamente routes/auth.js:
  POST /api/auth/login   — login con LDAP + emite JWT en cookie
  POST /api/auth/logout  — borra cookie
  GET  /api/auth/me      — devuelve info del usuario autenticado
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from jose import jwt
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core import config
from app.core.security import authenticate
from app.models.schemas import LoginRequest, UserInfo, UserPayload
from app.services.ad_service import AuthError, authenticate_user

logger = logging.getLogger("rdweb.auth")

# FIX-C2: Rate limiter basado en IP del cliente.
# Protege contra ataques de fuerza bruta en el endpoint de login.
limiter = Limiter(key_func=get_remote_address)

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _get_initials(name: str) -> str:
    parts = name.split()[:2]
    return "".join(p[0].upper() for p in parts if p)


@router.post("/login")
@limiter.limit("5/minute")  # FIX-C2: Máximo 5 intentos de login por minuto por IP
async def login(request: Request, body: LoginRequest, response: Response):
    # FIX-A2: Devolver HTTP 400 (Bad Request) si faltan campos,
    # en lugar de HTTP 200 con error en el body.
    if not body.username or not body.password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "Usuario y contraseña son requeridos", "code": "MISSING_FIELDS"},
        )

    try:
        # authenticate_user es bloqueante (LDAP I/O) → ejecutar en thread pool
        user = await asyncio.to_thread(authenticate_user, body.username.strip(), body.password)
    except AuthError as exc:
        logger.warning("[auth/login] %s", exc)
        if exc.code == "INVALID_CREDENTIALS":
            response.status_code = 401
            return {"error": "Credenciales incorrectas. Verifica tu usuario y contraseña.", "code": "INVALID_CREDENTIALS"}
        response.status_code = 500
        return {"error": "Error interno del servidor", "code": "INTERNAL_ERROR"}

    payload = {
        "username": user["username"],
        "displayName": user["displayName"],
        "email": user["email"],
        "domain": user["domain"],
        "groups": user["groups"],
        "privateMode": body.privateMode is True,
    }

    token = jwt.encode(
        {**payload, "exp": datetime.now(timezone.utc).timestamp() + config.JWT_EXPIRES_IN_SECONDS},
        config.JWT_SECRET,
        algorithm="HS256",
    )

    timeout_minutes = 240 if body.privateMode else 20
    response.set_cookie(
        key="rdweb_token",
        value=token,
        httponly=True,
        secure=config.NODE_ENV == "production",
        samesite="strict",
        max_age=timeout_minutes * 60,
        path="/",
    )

    return {
        "ok": True,
        "user": {
            "username": user["username"],
            "displayName": user["displayName"],
            "email": user["email"],
            "domain": user["domain"],
            "initials": _get_initials(user["displayName"]),
        },
    }


@router.post("/logout")
async def logout(response: Response):
    response.delete_cookie(key="rdweb_token", path="/")
    return {"ok": True}


@router.get("/me")
async def me(user: UserPayload = Depends(authenticate)):
    return {
        "username": user.username,
        "displayName": user.displayName,
        "email": user.email,
        "domain": user.domain,
        "initials": _get_initials(user.displayName),
        "privateMode": user.privateMode,
    }
