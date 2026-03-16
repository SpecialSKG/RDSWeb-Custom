# Walkthrough — Correcciones de Seguridad RDS Web Portal

## Cambios de Código Aplicados

### FASE 1: Vulnerabilidades Críticas

#### ✅ C5 — CORS (same-origin)

```diff:main.py
"""
RDWeb-Moderno Backend — Punto de entrada principal.

Ejecuta Uvicorn como servidor ASGI.  Diseñado para:
  - Desarrollo directo: ``poetry run uvicorn app.main:app --reload``
  - Empaquetado PyInstaller: el .exe invoca ``app.main:app`` internamente.
  - NSSM: captura stdout/stderr para rotación de logs.
"""

from __future__ import annotations

import logging
import multiprocessing
import sys

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core import config
from app.routers import apps, auth, launch

# ── Logging no-bufferizado → compatible con NSSM ─────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("rdweb")

# ── Aplicación FastAPI ────────────────────────────────────────────────────

app = FastAPI(
    title="RDWeb-Moderno Backend",
    version="1.0.0",
    docs_url="/api/docs" if config.NODE_ENV != "production" else None,
    redoc_url=None,
)

# ── CORS (equivalente a la config de Express) ────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:4200", "http://localhost:4300"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# ── Health check ──────────────────────────────────────────────────────────

@app.get("/api/health")
async def health():
    from datetime import datetime, timezone

    return {
        "status": "ok",
        "simulationMode": config.SIMULATION_MODE,
        "rdcbServer": config.RDCB_SERVER,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# ── Routers ───────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(apps.router)
app.include_router(launch.router)


# ── 404 catch-all ─────────────────────────────────────────────────────────

@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    return JSONResponse(status_code=404, content={"error": "Ruta no encontrada"})


# ── Error handler global ──────────────────────────────────────────────────

@app.exception_handler(500)
async def internal_error_handler(request: Request, exc):
    logger.exception("[Global Error]")
    return JSONResponse(status_code=500, content={"error": "Error interno del servidor"})


# ── Servidor Uvicorn ──────────────────────────────────────────────────────

def _banner() -> None:
    mode = "SIMULACION" if config.SIMULATION_MODE else "PRODUCCION"
    logger.info("")
    logger.info("  ========================================")
    logger.info("         RDWeb-Moderno  Backend (Py)      ")
    logger.info("    Servidor en puerto %s", config.PORT)
    logger.info("    Modo: %s", mode)
    logger.info("    RDCB: %s", config.RDCB_SERVER)
    logger.info("  ========================================")
    logger.info("")
    logger.info("  API Health: http://localhost:%s/api/health", config.PORT)
    logger.info("")


if __name__ == "__main__":
    # freeze_support() es OBLIGATORIO cuando se empaqueta con PyInstaller en
    # Windows y se usan workers > 1.  No afecta al comportamiento en desarrollo.
    multiprocessing.freeze_support()

    import uvicorn

    _banner()

    # Pasar el objeto app directamente en lugar del string "app.main:app"
    # para evitar problemas de importación cuando el cwd no es backend-py/.
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=config.PORT,
        log_level="info",
        # En Windows + NSSM, usar 1 worker.  PyInstaller + multiprocessing
        # en Windows puede causar bucles infinitos si no se maneja bien.
        workers=1,
    )
===
"""
RDWeb-Moderno Backend — Punto de entrada principal.

Ejecuta Uvicorn como servidor ASGI.  Diseñado para:
  - Desarrollo directo: ``poetry run uvicorn app.main:app --reload``
  - Empaquetado PyInstaller: el .exe invoca ``app.main:app`` internamente.
  - NSSM: captura stdout/stderr para rotación de logs.
"""

from __future__ import annotations

import logging
import multiprocessing
import sys

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core import config
from app.routers import apps, auth, launch

# ── Logging no-bufferizado → compatible con NSSM ─────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("rdweb")

# ── Aplicación FastAPI ────────────────────────────────────────────────────

app = FastAPI(
    title="RDWeb-Moderno Backend",
    version="1.0.0",
    docs_url="/api/docs" if config.NODE_ENV != "production" else None,
    redoc_url=None,
)

# ── CORS ──────────────────────────────────────────────────────────────────
# FIX-C5: En producción, frontend y backend comparten origen vía IIS + ARR
# (reverse proxy same-origin), por lo que CORS no es necesario.
# Solo se habilita en desarrollo, donde Angular corre en :4200 y el backend en :3000.
if config.NODE_ENV != "production":
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["http://localhost:4200", "http://localhost:4300"],
        allow_credentials=True,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Content-Type", "Authorization"],
    )

# ── Health check ──────────────────────────────────────────────────────────

@app.get("/api/health")
async def health():
    # FIX-A3: No exponer información de infraestructura interna (RDCB, modo simulación).
    # Solo devolver el estado del servicio y timestamp.
    from datetime import datetime, timezone

    return {
        "status": "ok",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


# ── Rate Limiting (FIX-C2) ────────────────────────────────────────────────
# Registrar el estado del limiter y su handler de excepción (HTTP 429)
# para que slowapi funcione correctamente con FastAPI.
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.routers.auth import limiter

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── Routers ───────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(apps.router)
app.include_router(launch.router)


# ── 404 catch-all ─────────────────────────────────────────────────────────

@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    return JSONResponse(status_code=404, content={"error": "Ruta no encontrada"})


# ── Error handler global ──────────────────────────────────────────────────

@app.exception_handler(500)
async def internal_error_handler(request: Request, exc):
    logger.exception("[Global Error]")
    return JSONResponse(status_code=500, content={"error": "Error interno del servidor"})


# ── Servidor Uvicorn ──────────────────────────────────────────────────────

def _banner() -> None:
    mode = "SIMULACION" if config.SIMULATION_MODE else "PRODUCCION"
    logger.info("")
    logger.info("  ========================================")
    logger.info("         RDWeb-Moderno  Backend (Py)      ")
    logger.info("    Servidor en puerto %s", config.PORT)
    logger.info("    Modo: %s", mode)
    logger.info("    RDCB: %s", config.RDCB_SERVER)
    logger.info("  ========================================")
    logger.info("")
    logger.info("  API Health: http://localhost:%s/api/health", config.PORT)
    logger.info("")


if __name__ == "__main__":
    # freeze_support() es OBLIGATORIO cuando se empaqueta con PyInstaller en
    # Windows y se usan workers > 1.  No afecta al comportamiento en desarrollo.
    multiprocessing.freeze_support()

    import uvicorn

    _banner()

    # Pasar el objeto app directamente en lugar del string "app.main:app"
    # para evitar problemas de importación cuando el cwd no es backend-py/.
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=config.PORT,
        log_level="info",
        # En Windows + NSSM, usar 1 worker.  PyInstaller + multiprocessing
        # en Windows puede causar bucles infinitos si no se maneja bien.
        workers=1,
    )
```

**Justificación:** En producción, IIS + ARR actúan como reverse proxy → frontend y backend comparten origen. CORS es innecesario y su presencia podría abrir superficie de ataque. Solo se activa en desarrollo (`NODE_ENV != production`).

---

#### ✅ C2 — Rate Limiting (login)

```diff:auth.py
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

from fastapi import APIRouter, Depends, Response
from jose import jwt

from app.core import config
from app.core.security import authenticate
from app.models.schemas import LoginRequest, UserInfo, UserPayload
from app.services.ad_service import AuthError, authenticate_user

logger = logging.getLogger("rdweb.auth")

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _get_initials(name: str) -> str:
    parts = name.split()[:2]
    return "".join(p[0].upper() for p in parts if p)


@router.post("/login")
async def login(body: LoginRequest, response: Response):
    if not body.username or not body.password:
        return {"error": "Usuario y contraseña son requeridos", "code": "MISSING_FIELDS"}

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
        samesite="lax",
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
===
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
```

**Configuración:** `slowapi` limita a **5 intentos/minuto por IP**. Al exceder el límite, responde `HTTP 429 Too Many Requests`. Se registró el handler en [main.py](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/main.py) para que FastAPI intercepte `RateLimitExceeded`.

> [!NOTE]
> Debe ejecutarse `poetry add slowapi` o `poetry install` para instalar la nueva dependencia.

---

#### ✅ C3 — PowerShell Injection (RDCB_SERVER)

```diff:rdcb_service.py
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
===
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

    # FIX-C3: Validar que RDCB_SERVER solo contenga caracteres válidos
    # de un FQDN/hostname para prevenir inyección de comandos PowerShell.
    # Solo se permiten: letras, números, puntos, guiones y guiones bajos.
    if not re.fullmatch(r"[a-zA-Z0-9._\-]+", rdcb):
        raise RuntimeError(f"RDCB_SERVER contiene caracteres no válidos: {rdcb!r}")

    # FIX-C3: Usar comillas simples alrededor del valor de RDCB para evitar
    # interpolación de variables o metacaracteres de PowerShell.
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
```

**Validación:** Regex `[a-zA-Z0-9._\-]+` permite solo caracteres válidos de FQDN. Si el valor contiene metacaracteres de PowerShell (`; | & $` etc.), se lanza `RuntimeError` antes de ejecutar el subproceso.

---

#### ✅ C6 — JWT Secret CSPRNG

```diff:installer.nsi
; =====================================================================
; Instalador NSIS - Portal RD Web (Refactorizado)
; =====================================================================

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "WordFunc.nsh"

; =====================================================================
; DEFINICIONES GENERALES
; =====================================================================
!define MyAppName "Portal RDS Web"
!define MyAppPublisher "MH-DINAFI-USC"
!define ServiceName "RDSWeb"

!ifndef MyAppVersion
  !define MyAppVersion "1.0.0"
!endif

!ifndef BackendType
  !define BackendType "express"
!endif

; =====================================================================
; MACROS REUTILIZABLES
; =====================================================================
; Ejecución centralizada y segura de PowerShell con manejo de errores
!macro ExecPowerShell ScriptPath Arguments
    Push $R0 ; Protegemos el valor original de $R0
    DetailPrint "Ejecutando: ${ScriptPath}..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "${ScriptPath}" ${Arguments}'
    Pop $R0  ; Obtenemos el Exit Code de PowerShell
    ${If} $R0 != 0
        MessageBox MB_ICONSTOP|MB_OK "Fallo crítico al ejecutar: ${ScriptPath}$\r$\nCódigo de error: $R0.$\r$\nRevise los logs en la carpeta destino para más detalles."
        Abort "Instalación abortada por fallo en script externo."
    ${EndIf}
    Pop $R0  ; Restauramos el valor original de $R0
!macroend

; Ejecución silenciosa para procesos de desinstalación (no detiene el proceso si falla)
!macro ExecPowerShellQuiet ScriptPath Arguments
    Push $R0
    DetailPrint "Desinstalando (Ejecutando script): ${ScriptPath}..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "${ScriptPath}" ${Arguments}'
    Pop $R0  ; Descartamos el Exit Code
    Pop $R0  ; Restauramos la pila
!macroend

; =====================================================================
; VARIABLES GLOBALES
; =====================================================================
Var Dialog

; -- Certificados --
Var CmbCert
Var TxtHost
Var ValHost
Var ValCertThumbprint

; -- Active Directory y Servidores --
Var TxtAdLdap
Var TxtAdBaseDn
Var TxtAdDomain
Var TxtAdUser
Var TxtAdPass
Var TxtSrvRdcb

Var ValAdLdap
Var ValAdBaseDn
Var ValAdDomain
Var ValAdUser
Var ValAdPass
Var ValSrvRdcb

; =====================================================================
; CONFIGURACIÓN DEL INSTALADOR Y UI
; =====================================================================
Name "${MyAppName}"
!ifndef OutFileExe
  !define OutFileExe "RDWeb-Portal-Installer.exe"
!endif
OutFile "${OutFileExe}"
InstallDir "C:\inetpub\wwwroot"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show

!define MUI_ICON "assets\installer\app-icon.ico"
!define MUI_UNICON "assets\installer\app-icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\installer\wizard-banner.bmp"
!define MUI_COMPONENTSPAGE_NODESC

; -- Orden de Páginas --
!insertmacro MUI_PAGE_WELCOME
!define MUI_PAGE_CUSTOMFUNCTION_SHOW PageADShow
Page custom PageADCreate PageADLeave
Page custom PageCertCreate PageCertLeave
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; -- Páginas de Desinstalación --
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; -- Idiomas --
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "English"

; =====================================================================
; LÓGICA: PÁGINA DE ACTIVE DIRECTORY
; =====================================================================
Function PageADCreate
    !insertmacro MUI_HEADER_TEXT "Configuración de Active Directory y Servidores" "Configure la conexión LDAP al controlador de dominio y los servidores del portal."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ; --- LDAP URL ---
    ${NSD_CreateLabel} 0 0u 100% 10u "URL LDAP del Domain Controller:"
    Pop $0
    ${NSD_CreateText} 0 10u 100% 12u ""
    Pop $TxtAdLdap

    ${NSD_CreateLabel} 0 25u 100% 10u "Base DN del dominio:"
    Pop $0
    ${NSD_CreateText} 0 35u 100% 12u ""
    Pop $TxtAdBaseDn

    ; --- Dominio y Credenciales ---
    ${NSD_CreateLabel} 0 50u 100% 10u "Dominio NetBIOS:"
    Pop $0
    ${NSD_CreateText} 0 60u 100% 12u ""
    Pop $TxtAdDomain

    ${NSD_CreateLabel} 0 75u 48% 10u "Cuenta servicio (UPN):"
    Pop $0
    ${NSD_CreateText} 0 85u 48% 12u ""
    Pop $TxtAdUser

    ${NSD_CreateLabel} 52% 75u 48% 10u "Contraseña AD:"
    Pop $0
    ${NSD_CreatePassword} 52% 85u 48% 12u ""
    Pop $TxtAdPass

    ${NSD_CreateLabel} 0 105u 100% 10u "Servidor RD Connection Broker:"
    Pop $0
    ${NSD_CreateText} 0 115u 100% 12u ""
    Pop $TxtSrvRdcb

    nsDialogs::Show
FunctionEnd

; =====================================================================
; CALLBACK: Mostrar / inicializar valores rápidos al mostrar la página AD
; =====================================================================
Function PageADShow
    ; Rellenar valores por defecto (rápidos) al mostrar la página
    ReadEnvStr $2 "LOGONSERVER"
    ReadEnvStr $3 "USERDNSDOMAIN"
    ${WordFind} "$2" "\" "-1" $2

    ; Calcular Base DN (si existe USERDNSDOMAIN)
    ${If} $3 == ""
        StrCpy $1 ""
    ${Else}
        Push $R0
        Push $R1
        Push $R2
        Push $R3
        Push $R4
        Push $R5

        StrCpy $R0 $3
        StrCpy $R1 ""
        StrCpy $R2 ""
        StrLen $R3 $R0
        
        ${For} $R4 0 $R3
            StrCpy $R5 $R0 1 $R4
            ${If} $R5 == "."
            ${OrIf} $R4 == $R3
                ${If} $R1 != ""
                    ${If} $R2 == ""
                        StrCpy $R2 "DC=$R1"
                    ${Else}
                        StrCpy $R2 "$R2,DC=$R1"
                    ${EndIf}
                    StrCpy $R1 ""
                ${EndIf}
            ${Else}
                StrCpy $R1 "$R1$R5"
            ${EndIf}
        ${Next}
        StrCpy $1 $R2

        Pop $R5
        Pop $R4
        Pop $R3
        Pop $R2
        Pop $R1
        Pop $R0
    ${EndIf}

    ${NSD_SetText} $TxtAdLdap "ldap://$2.$3"
    ${NSD_SetText} $TxtAdBaseDn "$1"
    ReadEnvStr $4 "USERDOMAIN"
    ${NSD_SetText} $TxtAdDomain "$4"
FunctionEnd

Function PageADLeave
    ${NSD_GetText} $TxtAdLdap $ValAdLdap
    ${NSD_GetText} $TxtAdBaseDn $ValAdBaseDn
    ${NSD_GetText} $TxtAdDomain $ValAdDomain
    ${NSD_GetText} $TxtAdUser $ValAdUser
    ${NSD_GetText} $TxtAdPass $ValAdPass
    ${NSD_GetText} $TxtSrvRdcb $ValSrvRdcb

    ${If} $ValAdLdap == ""
    ${OrIf} $ValAdBaseDn == ""
    ${OrIf} $ValAdDomain == ""
    ${OrIf} $ValAdUser == ""
    ${OrIf} $ValAdPass == ""
        MessageBox MB_ICONSTOP|MB_OK "Todos los campos de Active Directory son obligatorios."
        Abort
    ${EndIf}

    ${If} $ValSrvRdcb == ""
        MessageBox MB_ICONSTOP|MB_OK "Debe ingresar el servidor RD Connection Broker."
        Abort
    ${EndIf}
FunctionEnd

; =====================================================================
; LÓGICA: PÁGINA DE CERTIFICADO SSL
; =====================================================================
Function PageCertCreate
    !insertmacro MUI_HEADER_TEXT "Certificado SSL" "Seleccione el certificado SSL que se usará para el sitio HTTPS del portal."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 10u 100% 12u "Certificado:"
    Pop $0
    ${NSD_CreateDropList} 0 25u 100% 12u ""
    Pop $CmbCert

    ${NSD_CreateLabel} 0 50u 100% 12u "Nombre de host (FQDN):"
    Pop $0

    ReadEnvStr $0 "COMPUTERNAME"
    ReadEnvStr $1 "USERDNSDOMAIN"
    ${If} $1 != ""
        StrCpy $2 "$0.$1"
    ${Else}
        StrCpy $2 "$0"
    ${EndIf}
    ${NSD_CreateText} 0 65u 100% 12u "$2"
    Pop $TxtHost

    ; Extraer y listar certificados vía PowerShell
    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\enum-certs.ps1" w
    FileWrite $0 "$$certs = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $$_.HasPrivateKey -and $$_.NotAfter -gt (Get-Date) }$\r$\n"
    FileWrite $0 "$$certs_display = $$certs | ForEach-Object { $$_.Subject + ' (exp: ' + $$_.NotAfter.ToString('yyyy-MM-dd') + ')' }$\r$\n"
    FileWrite $0 "$$certs_thumb = $$certs | ForEach-Object { $$_.Thumbprint }$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllLines('$PLUGINSDIR\certs_list.txt', $$certs_display, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllLines('$PLUGINSDIR\certs_thumb.txt', $$certs_thumb, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileClose $0

    nsExec::Exec 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$PLUGINSDIR\enum-certs.ps1"'

    ; Cargar certificados en el ComboBox (Refactorizado con LogicLib)
    ClearErrors
    FileOpen $0 "$PLUGINSDIR\certs_list.txt" r
    ${If} $0 != ""
        ${Do}
            FileRead $0 $1
            IfErrors 0 +2
                ${ExitDo}
            
            ; Limpiar CRLF
            StrLen $2 $1
            IntOp $2 $2 - 2
            StrCpy $1 $1 $2
            
            ${If} $1 != ""
                ${NSD_CB_AddString} $CmbCert $1
            ${EndIf}
        ${Loop}
        FileClose $0
        SendMessage $CmbCert ${CB_SETCURSEL} 0 0
    ${Else}
        ${NSD_CB_AddString} $CmbCert "No se encontraron certificados válidos."
        SendMessage $CmbCert ${CB_SETCURSEL} 0 0
    ${EndIf}

    nsDialogs::Show
FunctionEnd

Function PageCertLeave
    ${NSD_GetText} $TxtHost $ValHost
    ${If} $ValHost == ""
        MessageBox MB_ICONSTOP|MB_OK "Debe ingresar el nombre de host del sitio (ej: portal.midominio.com)."
        Abort
    ${EndIf}

    SendMessage $CmbCert ${CB_GETCURSEL} 0 0
    Pop $0
    ${If} $0 == -1
        MessageBox MB_ICONSTOP|MB_OK "Debe seleccionar un certificado SSL válido para continuar."
        Abort
    ${EndIf}

    FileOpen $1 "$PLUGINSDIR\certs_thumb.txt" r
    ${If} $1 == ""
        MessageBox MB_ICONSTOP|MB_OK "No se pudo cargar la información de certificados (thumbprints)."
        Abort
    ${EndIf}
    
    ; Leer el thumbprint correspondiente a la selección
    StrCpy $2 0
    ${Do}
        FileRead $1 $3
        IfErrors 0 +2
            ${ExitDo}
        
        StrLen $4 $3
        IntOp $4 $4 - 2
        StrCpy $3 $3 $4
        
        ${If} $2 == $0
            StrCpy $ValCertThumbprint $3
            ${ExitDo}
        ${EndIf}
        IntOp $2 $2 + 1
    ${Loop}
    FileClose $1
FunctionEnd

; =====================================================================
; COMPONENTES / SECCIONES PRINCIPALES
; =====================================================================

Section "Prerrequisitos IIS (URL Rewrite 2.1 y ARR 3.0)" SEC_PREREQS
    SetOutPath "$TEMP"
    File "scripts\setup-iis-prereqs.ps1"
    File "scripts\setup-backend-service.ps1"
    File "scripts\setup-iis-site.ps1"

    SetOutPath "$TEMP\prereqs"
    File /r "prereqs\*"

    CreateDirectory "$INSTDIR\backend\logs"
    !insertmacro ExecPowerShell "$TEMP\setup-iis-prereqs.ps1" '-PrereqsDir "$TEMP\prereqs" -LogFile "$INSTDIR\backend\logs\install-prereqs.log"'
SectionEnd


Section "Backend ${BackendType} (API + Servicio Windows)" SEC_BACKEND
    DetailPrint "Deteniendo servicio/procesos existentes (si aplica)..."
    nsExec::Exec 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if (Get-Service -Name \"${ServiceName}\" -ErrorAction SilentlyContinue) { Stop-Service -Name \"${ServiceName}\" -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3 }"'
    nsExec::Exec 'taskkill /F /IM main.exe 2>NUL'
    nsExec::Exec 'taskkill /F /IM node.exe 2>NUL'

    !if "${BackendType}" == "python"
        SetOutPath "$INSTDIR\backend"
        File "backend\main.exe"
        File "backend\nssm.exe"
    !else
        SetOutPath "$INSTDIR\backend\src"
        File /r "backend\src\*"
        SetOutPath "$INSTDIR\backend\node_modules"
        File /r "backend\node_modules\*"
        SetOutPath "$INSTDIR\backend"
        File "backend\package.json"
        File "backend\nssm.exe"
        File "backend\node.exe"
    !endif

    ; --- Generar JWT Secreto VBS ---
    DetailPrint "Generando archivo .env..."
    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\gen-jwt.vbs" w
    FileWrite $0 'Randomize : Dim s, i : For i = 1 To 32 : s = s & Hex(Int((15 * Rnd) + 0)) : Next : WScript.StdOut.Write s'
    FileClose $0
    nsExec::ExecToStack 'cscript.exe //nologo "$PLUGINSDIR\gen-jwt.vbs"'
    Pop $0
    Pop $1 ; JWT_SECRET en $1

    ; --- Escritura de Configuración (.env) ---
    FileOpen $0 "$INSTDIR\backend\.env" w
    FileWrite $0 "# ============================================================$\r$\n"
    FileWrite $0 "# RDWeb Portal - Generado por el Instalador$\r$\n"
    FileWrite $0 "# ============================================================$\r$\n$\r$\n"
    FileWrite $0 "PORT=3000$\r$\nNODE_ENV=production$\r$\nJWT_SECRET=$1$\r$\nJWT_EXPIRES_IN=1h$\r$\n$\r$\n"
    FileWrite $0 "LDAP_URL=$ValAdLdap$\r$\nLDAP_BASE_DN=$ValAdBaseDn$\r$\nAD_DOMAIN=$ValAdDomain$\r$\n"
    FileWrite $0 "AD_SERVICE_USER=$ValAdUser$\r$\nAD_SERVICE_PASS=$ValAdPass$\r$\nRDCB_SERVER=$ValSrvRdcb$\r$\n$\r$\n"
    FileWrite $0 "RDP_GATEWAY_CREDENTIAL_SOURCE=0$\r$\nRDP_PROMPT_CREDENTIAL_ONCE=true$\r$\n"
    FileWrite $0 "RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT=true$\r$\nRDP_USE_MULTIMON=false$\r$\n"
    FileWrite $0 "RDP_SPAN_MONITORS=false$\r$\nSIMULATION_MODE=false$\r$\n"
    FileClose $0

    ; --- Configurar Servicio NSSM ---
    DetailPrint "Configurando servicio backend..."
    CreateDirectory "$INSTDIR\backend\logs"
    
    FileOpen $0 "$TEMP\svcpwd.dat" w
    FileWrite $0 $ValAdPass
    FileClose $0

    !insertmacro ExecPowerShell "$TEMP\setup-backend-service.ps1" '-BackendDir "$INSTDIR\backend" -ServiceName "${ServiceName}" -BackendType "${BackendType}" -ServiceUser "$ValAdUser" -ServiceDomain "$ValAdDomain" -CredentialFile "$TEMP\svcpwd.dat" -LogFile "$INSTDIR\backend\logs\install-service.log"'
    Delete "$TEMP\svcpwd.dat"
SectionEnd

Section "Frontend Angular (archivos estáticos IIS)" SEC_FRONTEND
    SetOutPath "$INSTDIR\frontend"
    File /r "frontend\*"

    DetailPrint "Configurando sitio IIS..."
    !insertmacro ExecPowerShell "$TEMP\setup-iis-site.ps1" '-SiteName "${MyAppName}" -FrontendDir "$INSTDIR\frontend" -CertThumbprint "$ValCertThumbprint" -HostName "$ValHost" -LogFile "$INSTDIR\backend\logs\install-iis-site.log"'

    SetOutPath "$INSTDIR\assets\installer"
    File "assets\installer\app-icon.ico"
    SetOutPath "$INSTDIR\scripts"
    File "scripts\uninstall-backend-service.ps1"
    File "scripts\uninstall-iis-site.ps1"

    WriteUninstaller "$INSTDIR\uninstall.exe"
    
    ; Registro en Agregar/Quitar Programas
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "DisplayName" "${MyAppName}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "DisplayIcon" "$INSTDIR\assets\installer\app-icon.ico"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "InstallLocation" "$\"$INSTDIR$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "Publisher" "${MyAppPublisher}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "DisplayVersion" "${MyAppVersion}"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "NoRepair" 1
SectionEnd

; =====================================================================
; DESINSTALADOR
; =====================================================================
Section "Uninstall"
    !insertmacro ExecPowerShellQuiet "$INSTDIR\scripts\uninstall-iis-site.ps1" '-SiteName "${MyAppName}"'
    !insertmacro ExecPowerShellQuiet "$INSTDIR\scripts\uninstall-backend-service.ps1" '-BackendDir "$INSTDIR\backend" -ServiceName "${ServiceName}"'

    DetailPrint "Eliminando archivos..."
    RMDir /r "$INSTDIR\backend"
    RMDir /r "$INSTDIR\frontend"
    RMDir /r "$INSTDIR\scripts"
    Delete "$INSTDIR\uninstall.exe"
    RMDir "$INSTDIR" 

    DetailPrint "Limpiando registro..."
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}"
SectionEnd
===
; =====================================================================
; Instalador NSIS - Portal RD Web (Refactorizado)
; =====================================================================

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "WordFunc.nsh"

; =====================================================================
; DEFINICIONES GENERALES
; =====================================================================
!define MyAppName "Portal RDS Web"
!define MyAppPublisher "MH-DINAFI-USC"
!define ServiceName "RDSWeb"

!ifndef MyAppVersion
  !define MyAppVersion "1.0.0"
!endif

!ifndef BackendType
  !define BackendType "express"
!endif

; =====================================================================
; MACROS REUTILIZABLES
; =====================================================================
; Ejecución centralizada y segura de PowerShell con manejo de errores
!macro ExecPowerShell ScriptPath Arguments
    Push $R0 ; Protegemos el valor original de $R0
    DetailPrint "Ejecutando: ${ScriptPath}..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "${ScriptPath}" ${Arguments}'
    Pop $R0  ; Obtenemos el Exit Code de PowerShell
    ${If} $R0 != 0
        MessageBox MB_ICONSTOP|MB_OK "Fallo crítico al ejecutar: ${ScriptPath}$\r$\nCódigo de error: $R0.$\r$\nRevise los logs en la carpeta destino para más detalles."
        Abort "Instalación abortada por fallo en script externo."
    ${EndIf}
    Pop $R0  ; Restauramos el valor original de $R0
!macroend

; Ejecución silenciosa para procesos de desinstalación (no detiene el proceso si falla)
!macro ExecPowerShellQuiet ScriptPath Arguments
    Push $R0
    DetailPrint "Desinstalando (Ejecutando script): ${ScriptPath}..."
    nsExec::ExecToLog '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "${ScriptPath}" ${Arguments}'
    Pop $R0  ; Descartamos el Exit Code
    Pop $R0  ; Restauramos la pila
!macroend

; =====================================================================
; VARIABLES GLOBALES
; =====================================================================
Var Dialog

; -- Certificados --
Var CmbCert
Var TxtHost
Var ValHost
Var ValCertThumbprint

; -- Active Directory y Servidores --
Var TxtAdLdap
Var TxtAdBaseDn
Var TxtAdDomain
Var TxtAdUser
Var TxtAdPass
Var TxtSrvRdcb

Var ValAdLdap
Var ValAdBaseDn
Var ValAdDomain
Var ValAdUser
Var ValAdPass
Var ValSrvRdcb

; =====================================================================
; CONFIGURACIÓN DEL INSTALADOR Y UI
; =====================================================================
Name "${MyAppName}"
!ifndef OutFileExe
  !define OutFileExe "RDWeb-Portal-Installer.exe"
!endif
OutFile "${OutFileExe}"
InstallDir "C:\inetpub\wwwroot"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show

!define MUI_ICON "assets\installer\app-icon.ico"
!define MUI_UNICON "assets\installer\app-icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\installer\wizard-banner.bmp"
!define MUI_COMPONENTSPAGE_NODESC

; -- Orden de Páginas --
!insertmacro MUI_PAGE_WELCOME
!define MUI_PAGE_CUSTOMFUNCTION_SHOW PageADShow
Page custom PageADCreate PageADLeave
Page custom PageCertCreate PageCertLeave
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; -- Páginas de Desinstalación --
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; -- Idiomas --
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "English"

; =====================================================================
; LÓGICA: PÁGINA DE ACTIVE DIRECTORY
; =====================================================================
Function PageADCreate
    !insertmacro MUI_HEADER_TEXT "Configuración de Active Directory y Servidores" "Configure la conexión LDAP al controlador de dominio y los servidores del portal."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ; --- LDAP URL ---
    ${NSD_CreateLabel} 0 0u 100% 10u "URL LDAP del Domain Controller:"
    Pop $0
    ${NSD_CreateText} 0 10u 100% 12u ""
    Pop $TxtAdLdap

    ${NSD_CreateLabel} 0 25u 100% 10u "Base DN del dominio:"
    Pop $0
    ${NSD_CreateText} 0 35u 100% 12u ""
    Pop $TxtAdBaseDn

    ; --- Dominio y Credenciales ---
    ${NSD_CreateLabel} 0 50u 100% 10u "Dominio NetBIOS:"
    Pop $0
    ${NSD_CreateText} 0 60u 100% 12u ""
    Pop $TxtAdDomain

    ${NSD_CreateLabel} 0 75u 48% 10u "Cuenta servicio (UPN):"
    Pop $0
    ${NSD_CreateText} 0 85u 48% 12u ""
    Pop $TxtAdUser

    ${NSD_CreateLabel} 52% 75u 48% 10u "Contraseña AD:"
    Pop $0
    ${NSD_CreatePassword} 52% 85u 48% 12u ""
    Pop $TxtAdPass

    ${NSD_CreateLabel} 0 105u 100% 10u "Servidor RD Connection Broker:"
    Pop $0
    ${NSD_CreateText} 0 115u 100% 12u ""
    Pop $TxtSrvRdcb

    nsDialogs::Show
FunctionEnd

; =====================================================================
; CALLBACK: Mostrar / inicializar valores rápidos al mostrar la página AD
; =====================================================================
Function PageADShow
    ; Rellenar valores por defecto (rápidos) al mostrar la página
    ReadEnvStr $2 "LOGONSERVER"
    ReadEnvStr $3 "USERDNSDOMAIN"
    ${WordFind} "$2" "\" "-1" $2

    ; Calcular Base DN (si existe USERDNSDOMAIN)
    ${If} $3 == ""
        StrCpy $1 ""
    ${Else}
        Push $R0
        Push $R1
        Push $R2
        Push $R3
        Push $R4
        Push $R5

        StrCpy $R0 $3
        StrCpy $R1 ""
        StrCpy $R2 ""
        StrLen $R3 $R0
        
        ${For} $R4 0 $R3
            StrCpy $R5 $R0 1 $R4
            ${If} $R5 == "."
            ${OrIf} $R4 == $R3
                ${If} $R1 != ""
                    ${If} $R2 == ""
                        StrCpy $R2 "DC=$R1"
                    ${Else}
                        StrCpy $R2 "$R2,DC=$R1"
                    ${EndIf}
                    StrCpy $R1 ""
                ${EndIf}
            ${Else}
                StrCpy $R1 "$R1$R5"
            ${EndIf}
        ${Next}
        StrCpy $1 $R2

        Pop $R5
        Pop $R4
        Pop $R3
        Pop $R2
        Pop $R1
        Pop $R0
    ${EndIf}

    ${NSD_SetText} $TxtAdLdap "ldap://$2.$3"
    ${NSD_SetText} $TxtAdBaseDn "$1"
    ReadEnvStr $4 "USERDOMAIN"
    ${NSD_SetText} $TxtAdDomain "$4"
FunctionEnd

Function PageADLeave
    ${NSD_GetText} $TxtAdLdap $ValAdLdap
    ${NSD_GetText} $TxtAdBaseDn $ValAdBaseDn
    ${NSD_GetText} $TxtAdDomain $ValAdDomain
    ${NSD_GetText} $TxtAdUser $ValAdUser
    ${NSD_GetText} $TxtAdPass $ValAdPass
    ${NSD_GetText} $TxtSrvRdcb $ValSrvRdcb

    ${If} $ValAdLdap == ""
    ${OrIf} $ValAdBaseDn == ""
    ${OrIf} $ValAdDomain == ""
    ${OrIf} $ValAdUser == ""
    ${OrIf} $ValAdPass == ""
        MessageBox MB_ICONSTOP|MB_OK "Todos los campos de Active Directory son obligatorios."
        Abort
    ${EndIf}

    ${If} $ValSrvRdcb == ""
        MessageBox MB_ICONSTOP|MB_OK "Debe ingresar el servidor RD Connection Broker."
        Abort
    ${EndIf}
FunctionEnd

; =====================================================================
; LÓGICA: PÁGINA DE CERTIFICADO SSL
; =====================================================================
Function PageCertCreate
    !insertmacro MUI_HEADER_TEXT "Certificado SSL" "Seleccione el certificado SSL que se usará para el sitio HTTPS del portal."
    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ${NSD_CreateLabel} 0 10u 100% 12u "Certificado:"
    Pop $0
    ${NSD_CreateDropList} 0 25u 100% 12u ""
    Pop $CmbCert

    ${NSD_CreateLabel} 0 50u 100% 12u "Nombre de host (FQDN):"
    Pop $0

    ReadEnvStr $0 "COMPUTERNAME"
    ReadEnvStr $1 "USERDNSDOMAIN"
    ${If} $1 != ""
        StrCpy $2 "$0.$1"
    ${Else}
        StrCpy $2 "$0"
    ${EndIf}
    ${NSD_CreateText} 0 65u 100% 12u "$2"
    Pop $TxtHost

    ; Extraer y listar certificados vía PowerShell
    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\enum-certs.ps1" w
    FileWrite $0 "$$certs = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $$_.HasPrivateKey -and $$_.NotAfter -gt (Get-Date) }$\r$\n"
    FileWrite $0 "$$certs_display = $$certs | ForEach-Object { $$_.Subject + ' (exp: ' + $$_.NotAfter.ToString('yyyy-MM-dd') + ')' }$\r$\n"
    FileWrite $0 "$$certs_thumb = $$certs | ForEach-Object { $$_.Thumbprint }$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllLines('$PLUGINSDIR\certs_list.txt', $$certs_display, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileWrite $0 "[System.IO.File]::WriteAllLines('$PLUGINSDIR\certs_thumb.txt', $$certs_thumb, (New-Object System.Text.UTF8Encoding($$false)))$\r$\n"
    FileClose $0

    nsExec::Exec 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File "$PLUGINSDIR\enum-certs.ps1"'

    ; Cargar certificados en el ComboBox (Refactorizado con LogicLib)
    ClearErrors
    FileOpen $0 "$PLUGINSDIR\certs_list.txt" r
    ${If} $0 != ""
        ${Do}
            FileRead $0 $1
            IfErrors 0 +2
                ${ExitDo}
            
            ; Limpiar CRLF
            StrLen $2 $1
            IntOp $2 $2 - 2
            StrCpy $1 $1 $2
            
            ${If} $1 != ""
                ${NSD_CB_AddString} $CmbCert $1
            ${EndIf}
        ${Loop}
        FileClose $0
        SendMessage $CmbCert ${CB_SETCURSEL} 0 0
    ${Else}
        ${NSD_CB_AddString} $CmbCert "No se encontraron certificados válidos."
        SendMessage $CmbCert ${CB_SETCURSEL} 0 0
    ${EndIf}

    nsDialogs::Show
FunctionEnd

Function PageCertLeave
    ${NSD_GetText} $TxtHost $ValHost
    ${If} $ValHost == ""
        MessageBox MB_ICONSTOP|MB_OK "Debe ingresar el nombre de host del sitio (ej: portal.midominio.com)."
        Abort
    ${EndIf}

    SendMessage $CmbCert ${CB_GETCURSEL} 0 0
    Pop $0
    ${If} $0 == -1
        MessageBox MB_ICONSTOP|MB_OK "Debe seleccionar un certificado SSL válido para continuar."
        Abort
    ${EndIf}

    FileOpen $1 "$PLUGINSDIR\certs_thumb.txt" r
    ${If} $1 == ""
        MessageBox MB_ICONSTOP|MB_OK "No se pudo cargar la información de certificados (thumbprints)."
        Abort
    ${EndIf}
    
    ; Leer el thumbprint correspondiente a la selección
    StrCpy $2 0
    ${Do}
        FileRead $1 $3
        IfErrors 0 +2
            ${ExitDo}
        
        StrLen $4 $3
        IntOp $4 $4 - 2
        StrCpy $3 $3 $4
        
        ${If} $2 == $0
            StrCpy $ValCertThumbprint $3
            ${ExitDo}
        ${EndIf}
        IntOp $2 $2 + 1
    ${Loop}
    FileClose $1
FunctionEnd

; =====================================================================
; COMPONENTES / SECCIONES PRINCIPALES
; =====================================================================

Section "Prerrequisitos IIS (URL Rewrite 2.1 y ARR 3.0)" SEC_PREREQS
    SetOutPath "$TEMP"
    File "scripts\setup-iis-prereqs.ps1"
    File "scripts\setup-backend-service.ps1"
    File "scripts\setup-iis-site.ps1"

    SetOutPath "$TEMP\prereqs"
    File /r "prereqs\*"

    CreateDirectory "$INSTDIR\backend\logs"
    !insertmacro ExecPowerShell "$TEMP\setup-iis-prereqs.ps1" '-PrereqsDir "$TEMP\prereqs" -LogFile "$INSTDIR\backend\logs\install-prereqs.log"'
SectionEnd


Section "Backend ${BackendType} (API + Servicio Windows)" SEC_BACKEND
    DetailPrint "Deteniendo servicio/procesos existentes (si aplica)..."
    nsExec::Exec 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if (Get-Service -Name \"${ServiceName}\" -ErrorAction SilentlyContinue) { Stop-Service -Name \"${ServiceName}\" -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3 }"'
    nsExec::Exec 'taskkill /F /IM main.exe 2>NUL'
    nsExec::Exec 'taskkill /F /IM node.exe 2>NUL'

    !if "${BackendType}" == "python"
        SetOutPath "$INSTDIR\backend"
        File "backend\main.exe"
        File "backend\nssm.exe"
    !else
        SetOutPath "$INSTDIR\backend\src"
        File /r "backend\src\*"
        SetOutPath "$INSTDIR\backend\node_modules"
        File /r "backend\node_modules\*"
        SetOutPath "$INSTDIR\backend"
        File "backend\package.json"
        File "backend\nssm.exe"
        File "backend\node.exe"
    !endif

    ; --- FIX-C6: Generar JWT Secreto con CSPRNG de PowerShell ---
    ; Reemplaza VBScript Rnd() (no criptográfico) por
    ; [System.Security.Cryptography.RandomNumberGenerator] (CSPRNG).
    ; Genera 32 bytes aleatorios → 64 caracteres hex (256 bits de entropía).
    DetailPrint "Generando archivo .env..."
    InitPluginsDir
    FileOpen $0 "$PLUGINSDIR\gen-jwt.ps1" w
    FileWrite $0 "$$bytes = New-Object byte[] 32$\r$\n"
    FileWrite $0 "[System.Security.Cryptography.RandomNumberGenerator]::Fill($$bytes)$\r$\n"
    FileWrite $0 "[System.Console]::Write(([BitConverter]::ToString($$bytes) -replace '-',''))$\r$\n"
    FileClose $0
    nsExec::ExecToStack '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -NoProfile -File "$PLUGINSDIR\gen-jwt.ps1"'
    Pop $0
    Pop $1 ; JWT_SECRET en $1 (64 caracteres hex, 256 bits CSPRNG)

    ; --- Escritura de Configuración (.env) ---
    FileOpen $0 "$INSTDIR\backend\.env" w
    FileWrite $0 "# ============================================================$\r$\n"
    FileWrite $0 "# RDWeb Portal - Generado por el Instalador$\r$\n"
    FileWrite $0 "# ============================================================$\r$\n$\r$\n"
    FileWrite $0 "PORT=3000$\r$\nNODE_ENV=production$\r$\nJWT_SECRET=$1$\r$\nJWT_EXPIRES_IN=1h$\r$\n$\r$\n"
    FileWrite $0 "LDAP_URL=$ValAdLdap$\r$\nLDAP_BASE_DN=$ValAdBaseDn$\r$\nAD_DOMAIN=$ValAdDomain$\r$\n"
    FileWrite $0 "AD_SERVICE_USER=$ValAdUser$\r$\nAD_SERVICE_PASS=$ValAdPass$\r$\nRDCB_SERVER=$ValSrvRdcb$\r$\n$\r$\n"
    FileWrite $0 "RDP_GATEWAY_CREDENTIAL_SOURCE=0$\r$\nRDP_PROMPT_CREDENTIAL_ONCE=true$\r$\n"
    FileWrite $0 "RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT=true$\r$\nRDP_USE_MULTIMON=false$\r$\n"
    FileWrite $0 "RDP_SPAN_MONITORS=false$\r$\nSIMULATION_MODE=false$\r$\n"
    FileClose $0

    ; --- Configurar Servicio NSSM ---
    DetailPrint "Configurando servicio backend..."
    CreateDirectory "$INSTDIR\backend\logs"
    
    FileOpen $0 "$TEMP\svcpwd.dat" w
    FileWrite $0 $ValAdPass
    FileClose $0

    !insertmacro ExecPowerShell "$TEMP\setup-backend-service.ps1" '-BackendDir "$INSTDIR\backend" -ServiceName "${ServiceName}" -BackendType "${BackendType}" -ServiceUser "$ValAdUser" -ServiceDomain "$ValAdDomain" -CredentialFile "$TEMP\svcpwd.dat" -LogFile "$INSTDIR\backend\logs\install-service.log"'
    Delete "$TEMP\svcpwd.dat"
SectionEnd

Section "Frontend Angular (archivos estáticos IIS)" SEC_FRONTEND
    SetOutPath "$INSTDIR\frontend"
    File /r "frontend\*"

    DetailPrint "Configurando sitio IIS..."
    !insertmacro ExecPowerShell "$TEMP\setup-iis-site.ps1" '-SiteName "${MyAppName}" -FrontendDir "$INSTDIR\frontend" -CertThumbprint "$ValCertThumbprint" -HostName "$ValHost" -LogFile "$INSTDIR\backend\logs\install-iis-site.log"'

    SetOutPath "$INSTDIR\assets\installer"
    File "assets\installer\app-icon.ico"
    SetOutPath "$INSTDIR\scripts"
    File "scripts\uninstall-backend-service.ps1"
    File "scripts\uninstall-iis-site.ps1"

    WriteUninstaller "$INSTDIR\uninstall.exe"
    
    ; Registro en Agregar/Quitar Programas
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "DisplayName" "${MyAppName}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "DisplayIcon" "$INSTDIR\assets\installer\app-icon.ico"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "InstallLocation" "$\"$INSTDIR$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "Publisher" "${MyAppPublisher}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "DisplayVersion" "${MyAppVersion}"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}" "NoRepair" 1
SectionEnd

; =====================================================================
; DESINSTALADOR
; =====================================================================
Section "Uninstall"
    !insertmacro ExecPowerShellQuiet "$INSTDIR\scripts\uninstall-iis-site.ps1" '-SiteName "${MyAppName}"'
    !insertmacro ExecPowerShellQuiet "$INSTDIR\scripts\uninstall-backend-service.ps1" '-BackendDir "$INSTDIR\backend" -ServiceName "${ServiceName}"'

    DetailPrint "Eliminando archivos..."
    RMDir /r "$INSTDIR\backend"
    RMDir /r "$INSTDIR\frontend"
    RMDir /r "$INSTDIR\scripts"
    Delete "$INSTDIR\uninstall.exe"
    RMDir "$INSTDIR" 

    DetailPrint "Limpiando registro..."
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${MyAppName}"
SectionEnd
```

**Mejora:** VBScript `Rnd()` → `[System.Security.Cryptography.RandomNumberGenerator]::Fill()`. Genera 32 bytes (256 bits) con un CSPRNG del sistema operativo, convertidos a 64 caracteres hex.

---

### FASE 2: Vulnerabilidades Altas

#### ✅ A2 — Login HTTP 400

En [auth.py](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/routers/auth.py), campos faltantes ahora lanzan `HTTPException(status_code=400)` en lugar de retornar `200 OK` con error en el body.

#### ✅ A3 — Health endpoint sanitizado

En [main.py](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/main.py), `/api/health` ya no expone `rdcbServer` ni `simulationMode`. Solo retorna `status` y `timestamp`.

#### ✅ A6 — LDAP Timeout

```diff:ad_service.py
"""
Servicio de autenticación contra Active Directory vía LDAP (ldap3).

Replica exactamente la lógica del adService.js original:
  - Modo simulación con usuarios ficticios.
  - Modo real: bind con cuenta de servicio → buscar usuario → bind con credenciales del usuario.
"""

from __future__ import annotations

import logging
from typing import Any

from ldap3 import SUBTREE, Connection, Server, Tls
from ldap3.core.exceptions import LDAPBindError, LDAPException

from app.core import config

logger = logging.getLogger("rdweb.ad")

# ── Usuarios simulados ────────────────────────────────────────────────────

SIMULATED_USERS: list[dict[str, Any]] = [
    {
        "username": "administrador",
        "password": "Admin1234!",
        "displayName": "Administrador",
        "email": "admin@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users", "Domain Admins", "Contabilidad", "Desarrollo"],
    },
    {
        "username": "juan.perez",
        "password": "Usuario1234!",
        "displayName": "Juan Pérez",
        "email": "juan.perez@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users", "Contabilidad"],
    },
    {
        "username": "maria.garcia",
        "password": "Usuario1234!",
        "displayName": "María García",
        "email": "maria.garcia@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users", "Desarrollo"],
    },
    {
        "username": "carlos.lopez",
        "password": "Usuario1234!",
        "displayName": "Carlos López",
        "email": "carlos.lopez@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users", "RRHH"],
    },
    {
        "username": "demo",
        "password": "demo",
        "displayName": "Usuario Demo",
        "email": "demo@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users"],
    },
]


# ── Helpers ────────────────────────────────────────────────────────────────

def _parse_username(username: str) -> tuple[str, str]:
    """Normaliza el nombre de usuario.

    Retorna (domain, clean_user).
    """
    if "\\" in username:
        domain, clean_user = username.split("\\", 1)
        return domain.upper(), clean_user
    if "@" in username:
        clean_user, domain_suffix = username.split("@", 1)
        return domain_suffix.split(".")[0].upper(), clean_user
    return config.AD_DOMAIN, username


def _extract_groups(member_of: list[str] | str | None) -> list[str]:
    if not member_of:
        return []
    entries = member_of if isinstance(member_of, list) else [member_of]
    groups: list[str] = []
    for dn in entries:
        cn_part = dn.split(",")[0]
        if cn_part.upper().startswith("CN="):
            groups.append(cn_part[3:])
    return groups


# ── Excepciones propias ───────────────────────────────────────────────────

class AuthError(Exception):
    def __init__(self, message: str, code: str):
        super().__init__(message)
        self.code = code


# ── Autenticación ─────────────────────────────────────────────────────────

def authenticate_user(username: str, password: str) -> dict[str, Any]:
    """Autentica un usuario contra AD o en modo simulación.

    Esta función es bloqueante (I/O de red LDAP).  Se debe ejecutar en
    un thread pool desde el contexto asíncrono de FastAPI.
    """
    domain, clean_user = _parse_username(username)

    # ── MODO SIMULACIÓN ──────────────────────────────────────────────
    if config.SIMULATION_MODE:
        found = next(
            (u for u in SIMULATED_USERS if u["username"].lower() == clean_user.lower() and u["password"] == password),
            None,
        )
        if not found:
            raise AuthError("Credenciales incorrectas", "INVALID_CREDENTIALS")
        return {
            "username": found["username"],
            "displayName": found["displayName"],
            "email": found["email"],
            "domain": found["domain"],
            "groups": found["groups"],
        }

    # ── MODO REAL — ldap3 ────────────────────────────────────────────
    tls_config = Tls(validate=0)  # en prod: validate=ssl.CERT_REQUIRED + ca_certs
    server = Server(config.LDAP_URL, use_ssl=config.LDAP_URL.startswith("ldaps"), tls=tls_config, get_info="ALL")

    # 1) Bind con cuenta de servicio para buscar el DN del usuario
    try:
        svc_conn = Connection(
            server,
            user=config.AD_SERVICE_USER,
            password=config.AD_SERVICE_PASS,
            auto_bind=True,
            raise_exceptions=True,
            read_only=True,
        )
    except LDAPException as exc:
        logger.error("No se pudo conectar al AD con la cuenta de servicio: %s", exc)
        raise AuthError("No se pudo conectar al servidor de Active Directory.", "AD_UNREACHABLE") from exc

    try:
        search_filter = f"(sAMAccountName={_ldap_escape(clean_user)})"
        svc_conn.search(
            search_base=config.LDAP_BASE_DN,
            search_filter=search_filter,
            search_scope=SUBTREE,
            attributes=["displayName", "mail", "memberOf", "sAMAccountName", "userPrincipalName"],
        )

        if not svc_conn.entries:
            raise AuthError("Usuario no encontrado en Active Directory.", "USER_NOT_FOUND")

        entry = svc_conn.entries[0]
        user_dn = str(entry.entry_dn)
    finally:
        svc_conn.unbind()

    # 2) Bind con las credenciales del usuario para validarlas
    try:
        user_conn = Connection(server, user=user_dn, password=password, auto_bind=True, raise_exceptions=True)
        user_conn.unbind()
    except LDAPBindError as exc:
        msg = str(exc)
        if "invalidCredentials" in msg or "52e" in msg:
            raise AuthError("Credenciales incorrectas. Verifica tu usuario y contraseña.", "INVALID_CREDENTIALS") from exc
        raise AuthError("No se pudo conectar al servidor de Active Directory.", "AD_UNREACHABLE") from exc

    # 3) Extraer atributos
    groups = _extract_groups(entry.memberOf.values if hasattr(entry, "memberOf") and entry.memberOf else [])
    sam = str(entry.sAMAccountName) if hasattr(entry, "sAMAccountName") and entry.sAMAccountName else clean_user
    display_name = str(entry.displayName) if hasattr(entry, "displayName") and entry.displayName else clean_user
    mail = ""
    if hasattr(entry, "mail") and entry.mail:
        mail = str(entry.mail)
    elif hasattr(entry, "userPrincipalName") and entry.userPrincipalName:
        mail = str(entry.userPrincipalName)

    logger.info("Auth OK → usuario: %s, grupos (%d): [%s]", sam, len(groups), ", ".join(groups))

    return {
        "username": sam,
        "displayName": display_name,
        "email": mail,
        "domain": domain,
        "groups": groups,
    }


def _ldap_escape(value: str) -> str:
    """Escapa caracteres especiales para filtros LDAP (RFC 4515)."""
    replacements = {
        "\\": "\\5c",
        "*": "\\2a",
        "(": "\\28",
        ")": "\\29",
        "\x00": "\\00",
    }
    result = value
    for char, escaped in replacements.items():
        result = result.replace(char, escaped)
    return result
===
"""
Servicio de autenticación contra Active Directory vía LDAP (ldap3).

Replica exactamente la lógica del adService.js original:
  - Modo simulación con usuarios ficticios.
  - Modo real: bind con cuenta de servicio → buscar usuario → bind con credenciales del usuario.
"""

from __future__ import annotations

import logging
from typing import Any

from ldap3 import SUBTREE, Connection, Server, Tls
from ldap3.core.exceptions import LDAPBindError, LDAPException

from app.core import config

logger = logging.getLogger("rdweb.ad")

# ── Usuarios simulados ────────────────────────────────────────────────────

SIMULATED_USERS: list[dict[str, Any]] = [
    {
        "username": "administrador",
        "password": "Admin1234!",
        "displayName": "Administrador",
        "email": "admin@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users", "Domain Admins", "Contabilidad", "Desarrollo"],
    },
    {
        "username": "juan.perez",
        "password": "Usuario1234!",
        "displayName": "Juan Pérez",
        "email": "juan.perez@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users", "Contabilidad"],
    },
    {
        "username": "maria.garcia",
        "password": "Usuario1234!",
        "displayName": "María García",
        "email": "maria.garcia@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users", "Desarrollo"],
    },
    {
        "username": "carlos.lopez",
        "password": "Usuario1234!",
        "displayName": "Carlos López",
        "email": "carlos.lopez@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users", "RRHH"],
    },
    {
        "username": "demo",
        "password": "demo",
        "displayName": "Usuario Demo",
        "email": "demo@lab-mh.local",
        "domain": "LAB-MH",
        "groups": ["RemoteApp Users"],
    },
]


# ── Helpers ────────────────────────────────────────────────────────────────

def _parse_username(username: str) -> tuple[str, str]:
    """Normaliza el nombre de usuario.

    Retorna (domain, clean_user).
    """
    if "\\" in username:
        domain, clean_user = username.split("\\", 1)
        return domain.upper(), clean_user
    if "@" in username:
        clean_user, domain_suffix = username.split("@", 1)
        return domain_suffix.split(".")[0].upper(), clean_user
    return config.AD_DOMAIN, username


def _extract_groups(member_of: list[str] | str | None) -> list[str]:
    if not member_of:
        return []
    entries = member_of if isinstance(member_of, list) else [member_of]
    groups: list[str] = []
    for dn in entries:
        cn_part = dn.split(",")[0]
        if cn_part.upper().startswith("CN="):
            groups.append(cn_part[3:])
    return groups


# ── Excepciones propias ───────────────────────────────────────────────────

class AuthError(Exception):
    def __init__(self, message: str, code: str):
        super().__init__(message)
        self.code = code


# ── Autenticación ─────────────────────────────────────────────────────────

def authenticate_user(username: str, password: str) -> dict[str, Any]:
    """Autentica un usuario contra AD o en modo simulación.

    Esta función es bloqueante (I/O de red LDAP).  Se debe ejecutar en
    un thread pool desde el contexto asíncrono de FastAPI.
    """
    domain, clean_user = _parse_username(username)

    # ── MODO SIMULACIÓN ──────────────────────────────────────────────
    if config.SIMULATION_MODE:
        found = next(
            (u for u in SIMULATED_USERS if u["username"].lower() == clean_user.lower() and u["password"] == password),
            None,
        )
        if not found:
            raise AuthError("Credenciales incorrectas", "INVALID_CREDENTIALS")
        return {
            "username": found["username"],
            "displayName": found["displayName"],
            "email": found["email"],
            "domain": found["domain"],
            "groups": found["groups"],
        }

    # ── MODO REAL — ldap3 ────────────────────────────────────────────
    tls_config = Tls(validate=0)  # en prod: validate=ssl.CERT_REQUIRED + ca_certs
    server = Server(config.LDAP_URL, use_ssl=config.LDAP_URL.startswith("ldaps"), tls=tls_config, get_info="ALL")

    # 1) Bind con cuenta de servicio para buscar el DN del usuario
    try:
        # FIX-A6: receive_timeout evita bloqueos indefinidos si el DC no responde
        svc_conn = Connection(
            server,
            user=config.AD_SERVICE_USER,
            password=config.AD_SERVICE_PASS,
            auto_bind=True,
            raise_exceptions=True,
            read_only=True,
            receive_timeout=10,
        )
    except LDAPException as exc:
        logger.error("No se pudo conectar al AD con la cuenta de servicio: %s", exc)
        raise AuthError("No se pudo conectar al servidor de Active Directory.", "AD_UNREACHABLE") from exc

    try:
        search_filter = f"(sAMAccountName={_ldap_escape(clean_user)})"
        svc_conn.search(
            search_base=config.LDAP_BASE_DN,
            search_filter=search_filter,
            search_scope=SUBTREE,
            attributes=["displayName", "mail", "memberOf", "sAMAccountName", "userPrincipalName"],
        )

        if not svc_conn.entries:
            raise AuthError("Usuario no encontrado en Active Directory.", "USER_NOT_FOUND")

        entry = svc_conn.entries[0]
        user_dn = str(entry.entry_dn)
    finally:
        svc_conn.unbind()

    # 2) Bind con las credenciales del usuario para validarlas
    try:
        # FIX-A6: receive_timeout también en la conexión del usuario
        user_conn = Connection(server, user=user_dn, password=password, auto_bind=True, raise_exceptions=True, receive_timeout=10)
        user_conn.unbind()
    except LDAPBindError as exc:
        msg = str(exc)
        if "invalidCredentials" in msg or "52e" in msg:
            raise AuthError("Credenciales incorrectas. Verifica tu usuario y contraseña.", "INVALID_CREDENTIALS") from exc
        raise AuthError("No se pudo conectar al servidor de Active Directory.", "AD_UNREACHABLE") from exc

    # 3) Extraer atributos
    groups = _extract_groups(entry.memberOf.values if hasattr(entry, "memberOf") and entry.memberOf else [])
    sam = str(entry.sAMAccountName) if hasattr(entry, "sAMAccountName") and entry.sAMAccountName else clean_user
    display_name = str(entry.displayName) if hasattr(entry, "displayName") and entry.displayName else clean_user
    mail = ""
    if hasattr(entry, "mail") and entry.mail:
        mail = str(entry.mail)
    elif hasattr(entry, "userPrincipalName") and entry.userPrincipalName:
        mail = str(entry.userPrincipalName)

    logger.info("Auth OK → usuario: %s, grupos (%d): [%s]", sam, len(groups), ", ".join(groups))

    return {
        "username": sam,
        "displayName": display_name,
        "email": mail,
        "domain": domain,
        "groups": groups,
    }


def _ldap_escape(value: str) -> str:
    """Escapa caracteres especiales para filtros LDAP (RFC 4515)."""
    replacements = {
        "\\": "\\5c",
        "*": "\\2a",
        "(": "\\28",
        ")": "\\29",
        "\x00": "\\00",
    }
    result = value
    for char, escaped in replacements.items():
        result = result.replace(char, escaped)
    return result
```

Ambas conexiones LDAP (cuenta de servicio y usuario) ahora tienen `receive_timeout=10` segundos.

---

## Guías de Configuración del Servidor

### 📋 C1 — Habilitar LDAPS (TLS en Active Directory)

> [!IMPORTANT]
> Esto requiere un certificado SSL válido en el Domain Controller. No es un cambio de código.

**Paso 1: Instalar certificado en el DC**

El Domain Controller necesita un certificado cuyo **Subject** o **SAN** coincida con el FQDN del servidor. Opciones:
- **CA Empresarial (recomendado):** Si tienen Active Directory Certificate Services (AD CS), el DC solicita automáticamente un certificado `DomainController`.
- **Certificado manual:** Importar un certificado PFX en `LocalMachine\My` del DC con la plantilla de autenticación de servidor.

**Paso 2: Verificar que LDAPS funciona**

Desde cualquier equipo del dominio:
```powershell
# Probar conexión LDAPS (puerto 636)
Test-NetConnection -ComputerName SRV-DC.LAB-MH.LOCAL -Port 636
```

**Paso 3: Cambiar la configuración en `.env`**

```
LDAP_URL=ldaps://SRV-DC.LAB-MH.LOCAL
```

**Paso 4: Actualizar [ad_service.py](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/services/ad_service.py)**

La línea 130 actualmente tiene `Tls(validate=0)`. Una vez habilitado LDAPS con certificado válido:

```python
# ANTES (inseguro):
tls_config = Tls(validate=0)

# DESPUÉS (validación completa):
import ssl
tls_config = Tls(validate=ssl.CERT_REQUIRED)
# Si usa CA interna, especificar el certificado raíz:
# tls_config = Tls(validate=ssl.CERT_REQUIRED, ca_certs_file="C:\\certs\\ca-root.pem")
```

> [!TIP]
> Si la CA es interna (AD CS), exportar el certificado raíz desde `certutil -ca.cert ca-root.pem` en el DC y distribuirlo al servidor del portal.

---

### 📋 C4 — Headers HSTS y CSP en [web.config](file:///c:/DevTools/Proyectos/RDSWeb-Custom/frontend/web.config)

Agregar los siguientes headers dentro del bloque `<customHeaders>` existente en [web.config](file:///c:/DevTools/Proyectos/RDSWeb-Custom/frontend/web.config):

```xml
<httpProtocol>
  <customHeaders>
    <!-- Ya existentes -->
    <add name="X-Content-Type-Options" value="nosniff" />
    <add name="X-Frame-Options" value="SAMEORIGIN" />
    
    <!-- FIX-C4: Headers de seguridad adicionales -->
    <add name="Strict-Transport-Security" 
         value="max-age=31536000; includeSubDomains" />
    <add name="Content-Security-Policy" 
         value="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'" />
    <add name="Referrer-Policy" 
         value="strict-origin-when-cross-origin" />
    <add name="Permissions-Policy" 
         value="camera=(), microphone=(), geolocation=()" />
  </customHeaders>
</httpProtocol>
```

> [!WARNING]
> La directiva `style-src 'unsafe-inline'` es necesaria si Angular Material inyecta estilos dinámicos. Si tras probar el portal no hay errores de CSP en la consola del navegador, puede endurecerse a solo `'self'`.

---

### 📋 A1/A7 — Protección del archivo `.env` con ACLs

**Paso 1: Restringir permisos después de la instalación**

Ejecutar como Administrador en el servidor donde se desplegó el portal:

```powershell
# Definir rutas
$envFile = "C:\inetpub\wwwroot\backend\.env"
$serviceAccount = "LAB-MH\svc-rdweb"  # Cuenta de servicio configurada en el instalador

# Deshabilitar herencia y limpiar permisos actuales
$acl = Get-Acl $envFile
$acl.SetAccessRuleProtection($true, $false)

# Permitir: SYSTEM (lectura), cuenta de servicio (lectura), Administrators (full)
$rules = @(
    [System.Security.AccessControl.FileSystemAccessRule]::new(
        "NT AUTHORITY\SYSTEM", "ReadAndExecute", "Allow"),
    [System.Security.AccessControl.FileSystemAccessRule]::new(
        $serviceAccount, "ReadAndExecute", "Allow"),
    [System.Security.AccessControl.FileSystemAccessRule]::new(
        "BUILTIN\Administrators", "FullControl", "Allow")
)
foreach ($rule in $rules) { $acl.AddAccessRule($rule) }
Set-Acl -Path $envFile -AclObject $acl

Write-Host "ACLs restrictivos aplicados a $envFile"
```

**Paso 2 (futuro): Alternativas al `.env` en texto plano**

| Opción | Complejidad | Beneficio |
|--------|------------|-----------|
| **DPAPI** (Windows Data Protection) | Media | Cifra secretos con credencial de la cuenta de servicio |
| **Windows Credential Manager** | Media | Almacena credenciales fuera del sistema de archivos |
| **Azure Key Vault / HashiCorp Vault** | Alta | Gestión centralizada de secretos con rotación automática |

---

## Resumen de Archivos Modificados

| Archivo | Cambios |
|---------|---------|
| [main.py](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/main.py) | C5 CORS, A3 health, C2 slowapi registration |
| [auth.py](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/routers/auth.py) | C2 rate limiting, A2 HTTP 400 |
| [rdcb_service.py](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/services/rdcb_service.py) | C3 RDCB_SERVER validation |
| [ad_service.py](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/services/ad_service.py) | A6 receive_timeout=10 |
| [installer.nsi](file:///c:/DevTools/Proyectos/RDSWeb-Custom/installer.nsi) | C6 CSPRNG JWT secret |
| [pyproject.toml](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/pyproject.toml) | Added slowapi dependency |

> [!IMPORTANT]
> Después de estos cambios, ejecutar `poetry install` en `backend-py/` para instalar `slowapi`.
