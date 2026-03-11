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
