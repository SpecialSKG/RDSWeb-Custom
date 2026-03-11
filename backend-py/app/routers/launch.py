"""
Router de lanzamiento — /api/launch

Replica exactamente routes/launch.js:
  GET /api/launch/{alias}  — genera y descarga un archivo .rdp
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse, Response

from app.core.security import authenticate
from app.models.schemas import UserPayload
from app.services.rdcb_service import get_apps_for_user
from app.services.rdp_service import generate_desktop_rdp, generate_remote_app_rdp

logger = logging.getLogger("rdweb.launch")

router = APIRouter(prefix="/api/launch", tags=["launch"])


@router.get("/{alias}")
async def launch(alias: str, user: UserPayload = Depends(authenticate)):
    is_private = user.privateMode is not False

    try:
        result = await get_apps_for_user(user)
        all_resources = result["apps"] + result["desktops"]
        resource = next(
            (r for r in all_resources if (r.alias or "").lower() == alias.lower()),
            None,
        )

        if not resource:
            return JSONResponse(
                status_code=404,
                content={"error": "Aplicación no encontrada", "code": "APP_NOT_FOUND"},
            )

        if resource.rdpPath is None:
            rdp_content = generate_desktop_rdp(resource, user)
        else:
            rdp_content = generate_remote_app_rdp(resource, user, is_private)

        file_name = f"{resource.alias or 'launch'}.rdp"

        return Response(
            content=rdp_content,
            media_type="application/x-rdp",
            headers={
                "Content-Disposition": f'attachment; filename="{file_name}"',
                "Cache-Control": "no-store",
            },
        )
    except Exception as exc:
        logger.error("[launch/%s] %s", alias, exc)
        return JSONResponse(
            status_code=500,
            content={"error": "Error generando el archivo RDP", "code": "RDP_ERROR"},
        )
