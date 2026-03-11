"""
Router de aplicaciones — /api/apps

Replica exactamente routes/apps.js:
  GET /api/apps  — lista RemoteApps y escritorios del usuario autenticado.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse

from app.core.security import authenticate
from app.models.schemas import UserPayload
from app.services.rdcb_service import get_apps_for_user

logger = logging.getLogger("rdweb.apps")

router = APIRouter(prefix="/api/apps", tags=["apps"])


@router.get("")
async def list_apps(user: UserPayload = Depends(authenticate)):
    logger.info("GET /api/apps → usuario: %s", user.username)
    try:
        result = await get_apps_for_user(user)
        apps = result["apps"]
        desktops = result["desktops"]
        logger.info("Respuesta → %d apps, %d escritorios", len(apps), len(desktops))
        return {
            "ok": True,
            "apps": [a.model_dump() for a in apps],
            "desktops": [d.model_dump() for d in desktops],
        }
    except Exception as exc:
        logger.error("[apps/get] %s", exc)
        return JSONResponse(
            status_code=503,
            content={"error": "No se pudo obtener el catálogo de aplicaciones", "code": "RDCB_ERROR"},
        )
