"""
Configuración centralizada — lee variables desde el .env que genera el instalador.

El .env se busca en el directorio donde reside el ejecutable (PyInstaller) o,
en desarrollo, junto al archivo config.py.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

from dotenv import load_dotenv

# ── Resolver la ruta del .env dinámicamente ───────────────────────────────
# PyInstaller empaqueta en _MEIPASS, pero el .exe se ejecuta desde su carpeta
# real.  sys.executable apunta al .exe; en desarrollo apunta a python.exe.
if getattr(sys, "frozen", False):
    _base_dir = Path(sys.executable).resolve().parent
else:
    _base_dir = Path(__file__).resolve().parent.parent.parent  # app/core/config.py → backend-py/

_env_path = _base_dir / ".env"
load_dotenv(_env_path)


def _to_int(value: str | None, fallback: int) -> int:
    try:
        return int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return fallback


def _parse_expires_in(raw: str | None) -> int:
    """Convierte cadenas tipo '8h', '30m', '1d' a segundos."""
    if not raw:
        return 28800  # 8h
    raw = raw.strip().lower()
    m = re.fullmatch(r"(\d+)\s*([smhd]?)", raw)
    if not m:
        return 28800
    value, unit = int(m.group(1)), m.group(2)
    multiplier = {"s": 1, "m": 60, "h": 3600, "d": 86400}.get(unit, 1)
    return value * multiplier


# ── Valores de configuración ──────────────────────────────────────────────

PORT: int = _to_int(os.getenv("PORT"), 3000)
NODE_ENV: str = os.getenv("NODE_ENV", "development")

# JWT
JWT_SECRET: str = os.getenv("JWT_SECRET", "dev_secret_insecure_change_in_production")
JWT_EXPIRES_IN_RAW: str = os.getenv("JWT_EXPIRES_IN", "8h")
JWT_EXPIRES_IN_SECONDS: int = _parse_expires_in(JWT_EXPIRES_IN_RAW)

# LDAP / Active Directory
LDAP_URL: str = os.getenv("LDAP_URL", "ldap://dc01.lab-mh.local")
LDAP_BASE_DN: str = os.getenv("LDAP_BASE_DN", "DC=lab-mh,DC=local")
AD_DOMAIN: str = os.getenv("AD_DOMAIN", "LAB-MH")
AD_SERVICE_USER: str = os.getenv("AD_SERVICE_USER", "svc-rdweb@lab-mh.local")
AD_SERVICE_PASS: str = os.getenv("AD_SERVICE_PASS", "")

# RD Connection Broker
RDCB_SERVER: str = os.getenv("RDCB_SERVER", "SRV-APPS.LAB-MH.LOCAL")

# RDP
RDP_GATEWAY_CREDENTIAL_SOURCE: int = _to_int(os.getenv("RDP_GATEWAY_CREDENTIAL_SOURCE"), 0)
RDP_PROMPT_CREDENTIAL_ONCE: bool = os.getenv("RDP_PROMPT_CREDENTIAL_ONCE", "true").lower() != "false"
RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT: bool = os.getenv("RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT", "true").lower() != "false"
RDP_USE_MULTIMON: bool = os.getenv("RDP_USE_MULTIMON", "false").lower() == "true"
RDP_SPAN_MONITORS: bool = os.getenv("RDP_SPAN_MONITORS", "false").lower() == "true"

# Simulación
SIMULATION_MODE: bool = os.getenv("SIMULATION_MODE", "false").lower() == "true"
