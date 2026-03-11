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

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=config.PORT,
        log_level="info",
        # En Windows + NSSM, usar 1 worker.  PyInstaller + multiprocessing
        # en Windows puede causar bucles infinitos si no se maneja bien.
        workers=1,
    )
