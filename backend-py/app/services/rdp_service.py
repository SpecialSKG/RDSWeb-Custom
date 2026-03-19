"""
Servicio RDP — genera el contenido de archivos .rdp.

Replica exactamente rdpService.js: genera RemoteApp y Desktop RDP files.
"""

from __future__ import annotations

import re
import subprocess
import tempfile
import os
import logging

from app.core import config
from app.models.schemas import AppResource, UserPayload

logger = logging.getLogger(__name__)


def _normalize_collection_name(collection_name: str) -> str:
    name = collection_name.strip()
    name = re.sub(r"\s+", "_", name)
    name = re.sub(r"\W", "_", name)
    return name.upper()


def sign_rdp_content(rdp_content: str) -> bytes:
    """Firma el contenido RDP usando rdpsign.exe y el thumbprint configurado.

    Devuelve `bytes` con la representación UTF-16LE (con BOM) del .rdp firmado
    o del original si no hay thumbprint o si la firma falla.
    """
    thumbprint = getattr(config, "CERT_THUMBPRINT", None)

    # Preparar bytes del contenido en UTF-16LE con BOM
    original_bytes = b"\xff\xfe" + rdp_content.encode("utf-16le")

    if not thumbprint:
        return original_bytes

    temp_path = None
    try:
        tmp = tempfile.NamedTemporaryFile(suffix=".rdp", delete=False)
        temp_path = tmp.name
        tmp.close()

        # Escribir bytes (con BOM) para que rdpsign procese correctamente
        with open(temp_path, "wb") as f:
            f.write(original_bytes)

        # Ejecutar rdpsign (evitar shell=True para seguridad)
        cmd = ["rdpsign.exe", "/sha256", thumbprint, temp_path]
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            logger.error("rdpsign.exe falló: %s", result.stderr.strip())
            return original_bytes

        # Leer y devolver archivo firmado en binario
        with open(temp_path, "rb") as f:
            return f.read()

    except Exception as exc:  # pragma: no cover - environment-dependent
        logger.exception("Error firmando RDP: %s", exc)
        return original_bytes
    finally:
        if temp_path:
            try:
                os.remove(temp_path)
            except FileNotFoundError:
                pass
            except Exception:
                logger.debug("No se pudo eliminar temporal: %s", temp_path, exc_info=True)


def generate_remote_app_rdp(app: AppResource, user: UserPayload, is_private: bool = True) -> bytes:
    domain = user.domain or config.AD_DOMAIN
    session_timeout = 240 if is_private else 20  # noqa: F841 — kept for parity
    full_address = app.remoteServer or config.RDCB_SERVER
    collection_name = _normalize_collection_name(app.collectionName)

    lines: list[str] = [
        "redirectclipboard:i:1",
        "redirectprinters:i:1",
        "redirectcomports:i:1",
        "redirectsmartcards:i:1",
        "devicestoredirect:s:*",
        "drivestoredirect:s:*",
        "redirectdrives:i:1",
        "session bpp:i:32",
        f"prompt for credentials on client:i:{1 if config.RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT else 0}",
        f"span monitors:i:{1 if config.RDP_SPAN_MONITORS else 0}",
        f"use multimon:i:{1 if config.RDP_USE_MULTIMON else 0}",
        "remoteapplicationmode:i:1",
        "server port:i:3389",
        "allow font smoothing:i:1",
        f"promptcredentialonce:i:{1 if config.RDP_PROMPT_CREDENTIAL_ONCE else 0}",
        "gatewayusagemethod:i:1",
        "gatewayprofileusagemethod:i:1",
        f"gatewaycredentialssource:i:{config.RDP_GATEWAY_CREDENTIAL_SOURCE}",
        f"full address:s:{full_address}",
        f"alternate shell:s:{app.rdpPath}",
        f"remoteapplicationprogram:s:{app.rdpPath}",
        f"gatewayhostname:s:{full_address}",
        f"remoteapplicationname:s:{app.name}",
        "remoteapplicationcmdline:s:",
        f"workspace id:s:{full_address}",
        "use redirection server name:i:1",
    ]

    if collection_name:
        lines.append(f"loadbalanceinfo:s:tsv://MS Terminal Services Plugin.1.{collection_name}")

    content = "\r\n".join(lines) + "\r\n"
    return sign_rdp_content(content)


def generate_desktop_rdp(desktop: AppResource, user: UserPayload) -> bytes:
    domain = user.domain or config.AD_DOMAIN
    username = f"{domain}\\{user.username}"
    full_address = desktop.remoteServer or config.RDCB_SERVER

    lines: list[str] = [
        "screen mode id:i:2",
        "use multimon:i:0",
        "desktopwidth:i:1920",
        "desktopheight:i:1080",
        "session bpp:i:32",
        "compression:i:1",
        f"full address:s:{full_address}",
        f"gatewayhostname:s:{full_address}",
        "gatewayusagemethod:i:1",
        f"gatewaycredentialssource:i:{config.RDP_GATEWAY_CREDENTIAL_SOURCE}",
        "gatewayprofileusagemethod:i:1",
        f"username:s:{username}",
        "authentication level:i:3",
        "remoteapplicationmode:i:0",
        "redirectprinters:i:1",
        "redirectclipboard:i:1",
        "redirectdrives:i:0",
        "autoreconnection enabled:i:1",
    ]

    content = "\r\n".join(lines) + "\r\n"
    return sign_rdp_content(content)
