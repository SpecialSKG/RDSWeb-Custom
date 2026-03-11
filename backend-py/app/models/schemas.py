"""Modelos Pydantic compartidos."""

from __future__ import annotations

from pydantic import BaseModel


class UserPayload(BaseModel):
    """Payload almacenado dentro del JWT y disponible en req.user."""

    username: str
    displayName: str
    email: str
    domain: str
    groups: list[str] = []
    privateMode: bool = False


class UserInfo(BaseModel):
    """Información pública del usuario devuelta al frontend."""

    username: str
    displayName: str
    email: str
    domain: str
    initials: str


class AppResource(BaseModel):
    alias: str
    name: str
    rdpPath: str | None
    iconIndex: int = 0
    remoteServer: str
    folderName: str = ""
    collectionName: str = ""
    allowedGroups: list[str] = []


class LoginRequest(BaseModel):
    username: str
    password: str
    privateMode: bool = False
