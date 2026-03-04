# Contexto IA — RDSWeb-Custom

Separé el contexto en dos documentos para trabajar por capas:

- [CONTEXTO_IA_BACKEND.md](CONTEXTO_IA_BACKEND.md)
- [CONTEXTO_IA_FRONTEND.md](CONTEXTO_IA_FRONTEND.md)

Uso recomendado:

1. Cambios de API, AD, RDS o seguridad: abrir primero backend.
2. Cambios de UX, rutas, guards o consumo HTTP: abrir primero frontend.
3. Cambios funcionales completos: revisar ambos en paralelo.
