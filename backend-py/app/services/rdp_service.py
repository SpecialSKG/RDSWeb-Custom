"""
Servicio RDP — genera el contenido de archivos .rdp.

Replica exactamente rdpService.js: genera RemoteApp y Desktop RDP files.
"""

from __future__ import annotations

import re

from app.core import config
from app.models.schemas import AppResource, UserPayload


def _normalize_collection_name(collection_name: str) -> str:
    name = collection_name.strip()
    name = re.sub(r"\s+", "_", name)
    name = re.sub(r"\W", "_", name)
    return name.upper()


def generate_remote_app_rdp(app: AppResource, user: UserPayload, is_private: bool = True) -> str:
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

    lines.append(f"alternate full address:s:{full_address}")

    return "\r\n".join(lines)


def generate_desktop_rdp(desktop: AppResource, user: UserPayload) -> str:
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

    return "\r\n".join(lines)
