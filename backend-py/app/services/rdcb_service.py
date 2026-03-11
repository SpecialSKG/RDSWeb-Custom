"""
Servicio RDCB — consulta RemoteApps y escritorios disponibles.

Replica exactamente rdcbService.js:
  - Modo simulación con catálogo estático + filtro por grupos AD.
  - Modo real: ejecuta PowerShell (Get-RDRemoteApp) de forma asíncrona
    para no bloquear el event loop de FastAPI.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from typing import Any

from app.core import config
from app.models.schemas import AppResource, UserPayload

logger = logging.getLogger("rdweb.rdcb")


# ── Helpers de permisos (exacta replica de rdcbService.js) ────────────────

def _normalize_group_name(value: Any) -> str:
    if isinstance(value, dict):
        candidate = (
            value.get("name")
            or value.get("Name")
            or value.get("accountName")
            or value.get("AccountName")
            or value.get("distinguishedName")
            or value.get("DistinguishedName")
            or value.get("value")
            or value.get("Value")
            or ""
        )
    else:
        candidate = value

    raw = str(candidate or "").strip()
    if not raw:
        return ""

    if re.match(r"^CN=", raw, re.IGNORECASE):
        return raw.split(",")[0][3:].strip().lower()

    if "\\" in raw:
        return raw.rsplit("\\", 1)[-1].strip().lower()

    return raw.lower()


def _get_user_permission_set(user: UserPayload) -> set[str]:
    principals: list[str] = list(user.groups)
    username = user.username.strip()
    domain = (user.domain or config.AD_DOMAIN).strip()
    email = (user.email or "").strip()

    if username:
        principals.append(username)
        if domain:
            principals.append(f"{domain}\\{username}")
    if email:
        principals.append(email)
        upn_user = email.split("@")[0]
        if upn_user:
            principals.append(upn_user)

    return {_normalize_group_name(e) for e in principals if e}


def _is_resource_allowed(resource_groups: list[str], user_perm_set: set[str]) -> bool:
    if not resource_groups:
        return True
    normalized = [_normalize_group_name(g) for g in resource_groups if g]
    if not normalized:
        return True
    return any(g in user_perm_set for g in normalized)


# ── Catálogo simulado ─────────────────────────────────────────────────────

_SIMULATED_APPS: list[dict[str, Any]] = [
    {"alias": "MSWORD", "name": "Microsoft Word 2019", "rdpPath": "||MSWORD", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Microsoft Office", "collectionName": "Office Apps"},
    {"alias": "MSEXCEL", "name": "Microsoft Excel 2019", "rdpPath": "||MSEXCEL", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Microsoft Office", "collectionName": "Office Apps"},
    {"alias": "MSPOWERPOINT", "name": "Microsoft PowerPoint 2019", "rdpPath": "||MSPOWERPOINT", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Microsoft Office", "collectionName": "Office Apps"},
    {"alias": "MSOUTLOOK", "name": "Microsoft Outlook 2019", "rdpPath": "||MSOUTLOOK", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Microsoft Office", "collectionName": "Office Apps"},
    {"alias": "MSONENOTE", "name": "Microsoft OneNote 2019", "rdpPath": "||MSONENOTE", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Microsoft Office", "collectionName": "Office Apps"},
    {"alias": "NOTEPADPP", "name": "Notepad++", "rdpPath": "||NOTEPADPP", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Herramientas", "collectionName": "Utilidades"},
    {"alias": "PUTTY", "name": "PuTTY SSH Client", "rdpPath": "||PUTTY", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Herramientas", "collectionName": "Utilidades", "allowedGroups": ["Desarrollo", "Domain Admins"]},
    {"alias": "WINSCP", "name": "WinSCP", "rdpPath": "||WINSCP", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Herramientas", "collectionName": "Utilidades", "allowedGroups": ["Desarrollo", "Domain Admins"]},
    {"alias": "CALC", "name": "Calculadora", "rdpPath": "||CALC", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Herramientas", "collectionName": "Utilidades"},
    {"alias": "CHROME", "name": "Google Chrome", "rdpPath": "||CHROME", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Navegadores", "collectionName": "Web Browsers"},
    {"alias": "FIREFOX", "name": "Mozilla Firefox", "rdpPath": "||FIREFOX", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Navegadores", "collectionName": "Web Browsers"},
    {"alias": "MSEDGE", "name": "Microsoft Edge", "rdpPath": "||MSEDGE", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Navegadores", "collectionName": "Web Browsers"},
    {"alias": "ERP", "name": "Sistema ERP", "rdpPath": "||ERP", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Aplicaciones Empresariales", "collectionName": "Business Apps", "allowedGroups": ["Contabilidad", "Domain Admins"]},
    {"alias": "CRM", "name": "CRM Ventas", "rdpPath": "||CRM", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Aplicaciones Empresariales", "collectionName": "Business Apps", "allowedGroups": ["Contabilidad", "Domain Admins"]},
    {"alias": "NOMINAS", "name": "Sistema de Nóminas", "rdpPath": "||NOMINAS", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Aplicaciones Empresariales", "collectionName": "Business Apps", "allowedGroups": ["RRHH", "Domain Admins"]},
    {"alias": "CONTPAQ", "name": "CONTPAQi Contabilidad", "rdpPath": "||CONTPAQ", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Aplicaciones Empresariales", "collectionName": "Business Apps", "allowedGroups": ["Contabilidad", "Domain Admins"]},
    {"alias": "VSCODE", "name": "Visual Studio Code", "rdpPath": "||VSCODE", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Desarrollo", "collectionName": "Dev Tools", "allowedGroups": ["Desarrollo", "Domain Admins"]},
    {"alias": "SSMS", "name": "SQL Server Management Studio", "rdpPath": "||SSMS", "iconIndex": 0, "remoteServer": config.RDCB_SERVER, "folderName": "Desarrollo", "collectionName": "Dev Tools", "allowedGroups": ["Desarrollo", "Domain Admins"]},
]

_SIMULATED_DESKTOPS: list[dict[str, Any]] = [
    {"alias": "DESKTOP_DEFAULT", "name": "Escritorio Remoto", "rdpPath": None, "remoteServer": config.RDCB_SERVER, "folderName": "Escritorios"},
    {"alias": "DESKTOP_DEV", "name": "Escritorio Desarrollo", "rdpPath": None, "remoteServer": config.RDCB_SERVER, "folderName": "Escritorios", "allowedGroups": ["Desarrollo", "Domain Admins"]},
]


# ── Consulta principal ────────────────────────────────────────────────────

async def get_apps_for_user(user: UserPayload) -> dict[str, list[AppResource]]:
    logger.info(
        "getAppsForUser → usuario: %s, dominio: %s, grupos AD: [%s]",
        user.username, user.domain, ", ".join(user.groups),
    )
    perm_set = _get_user_permission_set(user)
    logger.info("Permission set (%d entradas): [%s]", len(perm_set), ", ".join(sorted(perm_set)))

    if config.SIMULATION_MODE:
        apps = [
            AppResource(**a)
            for a in _SIMULATED_APPS
            if _is_resource_allowed(a.get("allowedGroups", []), perm_set)
        ]
        desktops = [
            AppResource(**d)
            for d in _SIMULATED_DESKTOPS
            if _is_resource_allowed(d.get("allowedGroups", []), perm_set)
        ]
        logger.info("SIMULACIÓN → apps permitidas: %d, escritorios: %d", len(apps), len(desktops))
        return {"apps": apps, "desktops": desktops}

    # ── MODO REAL — PowerShell ────────────────────────────────────────
    rdcb = config.RDCB_SERVER
    ps_script = (
        "$WarningPreference = 'SilentlyContinue'; "
        "$ErrorActionPreference = 'Stop'; "
        "Import-Module RemoteDesktop -ErrorAction Stop; "
        f"$all = Get-RDRemoteApp -ConnectionBroker '{rdcb}' -ErrorAction Stop; "
        "$visible = @($all | Where-Object { $_.ShowInWebAccess -eq $true }); "
        "if ($visible.Count -gt 0) { "
        "  $visible | Select-Object DisplayName, Alias, FolderName, CollectionName, UserGroups "
        "  | ConvertTo-Json -Compress -Depth 5 "
        "} else { '[]' }"
    )

    logger.info("Ejecutando PowerShell contra %s...", rdcb)

    try:
        proc = await asyncio.create_subprocess_exec(
            "powershell.exe", "-NonInteractive", "-NoProfile", "-Command", ps_script,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout_bytes, stderr_bytes = await asyncio.wait_for(proc.communicate(), timeout=20)
    except asyncio.TimeoutError as exc:
        raise RuntimeError("Timeout ejecutando PowerShell contra el RDCB") from exc
    except OSError as exc:
        raise RuntimeError(f"No se pudo ejecutar powershell.exe: {exc}") from exc

    stdout_text = stdout_bytes.decode("utf-8", errors="replace")
    stderr_text = stderr_bytes.decode("utf-8", errors="replace")

    if proc.returncode != 0:
        logger.error("PowerShell stderr: %s", stderr_text[:1000])
        raise RuntimeError("No se pudo contactar al RD Connection Broker")

    logger.info("Salida raw PS (primeros 500 chars): %s", stdout_text[:500])

    # Extraer JSON del output (puede tener texto residual)
    start_idx = stdout_text.find("[")
    end_idx = stdout_text.rfind("]")
    json_string = stdout_text[start_idx : end_idx + 1] if start_idx != -1 and end_idx != -1 else "[]"

    raw = json.loads(json_string)
    apps_array: list[dict[str, Any]] = raw if isinstance(raw, list) else [raw]
    logger.info("RDCB devolvió %d apps totales", len(apps_array))

    all_apps: list[AppResource] = []
    for a in apps_array:
        user_groups = a.get("UserGroups", [])
        if not isinstance(user_groups, list):
            user_groups = [user_groups] if user_groups else []
        all_apps.append(
            AppResource(
                alias=a.get("Alias", ""),
                name=a.get("DisplayName", ""),
                rdpPath=f"||{a.get('Alias', '')}",
                iconIndex=0,
                remoteServer=rdcb,
                collectionName=a.get("CollectionName", ""),
                folderName=a.get("FolderName", "Aplicaciones"),
                allowedGroups=user_groups,
            )
        )

    filtered = [
        app for app in all_apps
        if _is_resource_allowed(app.allowedGroups, perm_set)
    ]

    for app in all_apps:
        allowed = _is_resource_allowed(app.allowedGroups, perm_set)
        logger.info(
            '  app "%s" allowedGroups=[%s] → %s',
            app.alias,
            ", ".join(_normalize_group_name(g) for g in app.allowedGroups),
            "PERMITIDA" if allowed else "DENEGADA",
        )

    logger.info("Apps después de filtrar: %d/%d", len(filtered), len(all_apps))
    return {"apps": filtered, "desktops": []}
