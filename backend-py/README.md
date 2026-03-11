# RDWeb-Moderno Backend — Python / FastAPI

Migración completa del backend Node.js/Express a Python 3.11+ / FastAPI.

## Estructura

```
backend-py/
├── main.py                  # Punto de entrada (uvicorn.run)
├── pyproject.toml           # Dependencias (Poetry)
├── backend.spec             # PyInstaller spec (genera main.exe)
├── .env.example             # Plantilla de variables de entorno
└── app/
    ├── core/
    │   ├── config.py        # Lectura dinámica del .env
    │   └── security.py      # Dependencia JWT (cookie rdweb_token)
    ├── models/
    │   └── schemas.py       # Modelos Pydantic
    ├── routers/
    │   ├── auth.py          # POST /login, /logout, GET /me
    │   ├── apps.py          # GET /api/apps
    │   └── launch.py        # GET /api/launch/{alias}
    └── services/
        ├── ad_service.py    # Autenticación LDAP (ldap3)
        ├── rdcb_service.py  # PowerShell → Get-RDRemoteApp
        └── rdp_service.py   # Generación de archivos .rdp
```

## Desarrollo rápido

```powershell
cd backend-py
poetry install
# Copiar .env.example → .env y ajustar valores
copy .env.example .env
# Ejecutar en desarrollo
poetry run python main.py
```

## Empaquetado como .exe

```powershell
cd backend-py
poetry install            # instala incluyendo dev dependencies (pyinstaller)
poetry run pyinstaller backend.spec
# Resultado: dist/main.exe
```

## Integración con el pipeline (build.ps1 + installer.iss + NSSM)

Consultar el archivo `PIPELINE.md` para las modificaciones necesarias.
