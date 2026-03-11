# Conversión a HTML plano

Archivos incluidos:
- `login-static.html`
- `apps-static.html`
- `desktops-static.html`
- `style.css`
- `script.js`

## Qué sí hacen
- Se pueden abrir como HTML plano en navegador.
- Conservan la estructura visual principal.
- Sirven como maqueta estática o punto de partida para migración.

## Qué ya no hacen
- No autentican contra ASP.NET.
- No leen Active Directory.
- No generan feed XML/XSL.
- No lanzan ActiveX ni cliente RDP real.
- No descargan `.rdp` automáticamente.

## Qué tendrías que rehacer si quieres funcionalidad real
- Login con backend propio.
- Generación o descarga de archivos `.rdp`.
- Listado dinámico de apps desde API o JSON.
- Cierre de sesión y manejo de sesión.
- Integración con RDS Gateway o broker.
