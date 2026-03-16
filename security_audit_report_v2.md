# 🔒 Auditoría de Seguridad y Paridad Funcional — RDS Web Portal (v2)

**Fecha:** 2026-03-16 (re-análisis)  
**Alcance:** `/backend-py`, `/frontend`, `/rd-web-antiguo`, `installer.nsi`, `/scripts`

---

## 0. Resumen de Cambios Detectados desde la v1

> [!TIP]
> Se detectaron mejoras significativas en los scripts de despliegue. Los archivos de backend-py no cambiaron.

| Archivo | Cambios Clave |
|---------|--------------|
| [web.config](file:///c:/DevTools/Proyectos/RDSWeb-Custom/frontend/web.config) | ✅ Agregada regla **HTTP → HTTPS redirect** (301 Permanent) · ✅ Regla SPA ahora excluye `/api/` evitando conflictos · ✅ `remove` antes de `mimeMap` para webmanifest (idempotencia) |
| [installer.nsi](file:///c:/DevTools/Proyectos/RDSWeb-Custom/installer.nsi) | ✅ Macro `ExecPowerShell` centralizada con **abort on error** · ✅ Separadas variables de credenciales (eliminadas las que no se usaban) · ✅ `PageADShow` callback refactorizado con `${For}/${Next}` · ✅ Macro `ExecPowerShellQuiet` para desinstalación |
| [setup-backend-service.ps1](file:///c:/DevTools/Proyectos/RDSWeb-Custom/scripts/setup-backend-service.ps1) | ✅ `[CmdletBinding()]` con `ValidateScript`, `ValidateSet` · ✅ Credenciales como **SecureString** (`ConvertTo-SecureString`) · ✅ Función `Invoke-NssmCommand` oculta argumentos sensibles en log · ✅ Bloque `finally` para limpieza segura · ✅ Documentación `.SYNOPSIS` completa |
| [setup-iis-site.ps1](file:///c:/DevTools/Proyectos/RDSWeb-Custom/scripts/setup-iis-site.ps1) | ✅ `[CmdletBinding()]` con `ValidatePattern('^[a-fA-F0-9]{40}$')` para thumbprint · ✅ Función `Wait-IisSiteStart` · ✅ Limpieza idempotente (borra AppPool previo) · ✅ Splatting para bindings |
| [setup-iis-prereqs.ps1](file:///c:/DevTools/Proyectos/RDSWeb-Custom/scripts/setup-iis-prereqs.ps1) | ✅ `[CmdletBinding()]` · ✅ Función reutilizable `Install-IisModule` · ✅ Reinicio IIS via `Restart-Service` nativo con fallback a `iisreset` · ✅ Verificación explícita de `$LASTEXITCODE` en `appcmd` |

---

## 1. Riesgos Críticos Encontrados

### 🔴 CRÍTICO — DEBEN resolverse antes de producción

| # | Componente | Vulnerabilidad | OWASP | Detalle |
|---|-----------|---------------|-------|---------|
| C1 | `backend-py` | **TLS no validado en LDAP** | A07:2021 | [ad_service.py:130](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/services/ad_service.py#L130) → `Tls(validate=0)` deshabilita validación de certificados. MITM posible en red interna para capturar credenciales. |
| C2 | `backend-py` | **Falta Rate Limiting en login** | A07:2021 | [auth.py:34](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/routers/auth.py#L34) — Sin protección contra fuerza bruta. |
| C3 | `backend-py` | **PowerShell injection vía RDCB_SERVER** | A03:2021 | [rdcb_service.py:142](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/services/rdcb_service.py#L142) — `config.RDCB_SERVER` interpolado directamente en f-string de PowerShell. Si `.env` es comprometido → ejecución de código. |
| C4 | `frontend` | **Faltan HSTS y CSP** | A05:2021 | [web.config:42-47](file:///c:/DevTools/Proyectos/RDSWeb-Custom/frontend/web.config#L42-L47) — Tiene `X-Content-Type-Options` y `X-Frame-Options` ✅ pero aún **faltan**: `Strict-Transport-Security`, `Content-Security-Policy`, `Referrer-Policy`, `Permissions-Policy`. |
| C5 | `backend-py` | **CORS hardcoded a localhost** | A05:2021 | [main.py:44](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/main.py#L44) — Solo permite `localhost:4200/4300`. En producción detrás de IIS reverse proxy, CORS debería ser dinámico o eliminarse por same-origin. |
| C6 | `installer` | **JWT Secret con PRNG no criptográfico** | A02:2021 | [installer.nsi:389](file:///c:/DevTools/Proyectos/RDSWeb-Custom/installer.nsi#L389) — VBScript `Rnd()` no es CSPRNG. 32 hex chars (128 bits) es longitud aceptable pero la fuente de aleatoriedad es débil. |

---

### 🟡 ALTO — Hallazgos importantes

| # | Componente | Vulnerabilidad | Detalle |
|---|-----------|---------------|---------|
| A1 | `backend-py` | **Credenciales AD en `.env` texto plano** | [config.py:63-64](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/core/config.py#L63-L64) — Sin cifrado ni vault. |
| A2 | `backend-py` | **Login devuelve 200 con error** | [auth.py:37](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/routers/auth.py#L37) — Campos faltantes → 200 con `{"error":...}` en vez de 400. |
| A3 | `backend-py` | **Health expone infra interna** | [main.py:56-61](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/main.py#L56-L61) — `rdcbServer`, `simulationMode` sin autenticación. |
| A4 | `backend-py` | **Grupos AD en JWT** | [auth.py:55](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/routers/auth.py#L55) — Lista completa de grupos expuesta en token; permisos no se re-evalúan hasta expiración. |
| A5 | `backend-py` | **Swagger en no-producción** | [main.py:37](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/main.py#L37) — `/api/docs` si `NODE_ENV ≠ production`. |
| A6 | `backend-py` | **Sin timeout en LDAP bind** | [ad_service.py:135-142](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/services/ad_service.py#L135-L142) — Conexiones sin `receive_timeout`. |
| A7 | `scripts` | **NSSM recibe contraseña como argumento** | [setup-backend-service.ps1:221](file:///c:/DevTools/Proyectos/RDSWeb-Custom/scripts/setup-backend-service.ps1#L221) — Aunque ahora usa SecureString internamente ✅, NSSM requiere texto plano en argumento de proceso, que es visible via `Get-Process`. |

---

### 🟢 BAJO — Mejoras opcionales

| # | Observación |
|---|------------|
| B1 | Cookie `SameSite=Lax` es correcto; evaluar `Strict` si el flujo lo permite. |
| B2 | Descarga `.rdp` via `<a>` funciona solo bajo same-origin (IIS reverse proxy). Correcto en prod. |
| B3 | No hay logging JSON estructurado (dificulta integración SIEM). |

---

## 2. Hallazgos Resueltos por los Cambios ✅

Los siguientes problemas del reporte v1 han sido **mitigados o resueltos**:

| Hallazgo Original | Estado | Cómo se resolvió |
|---|---|---|
| **Falta HTTP→HTTPS redirect** | ✅ Resuelto | `web.config` ahora tiene regla `Redirect to HTTPS` con `redirectType="Permanent"` (301) |
| **Contraseña escrita a temp sin SecureString** (scripts) | ✅ Mejorado | `setup-backend-service.ps1` ahora convierte a `SecureString` inmediatamente tras leer el archivo, con limpieza en `finally` |
| **Scripts sin validación de parámetros** | ✅ Resuelto | Todos usan `[CmdletBinding()]`, `ValidateScript`, `ValidatePattern`, `ValidateSet`, `ValidateRange` |
| **Sin abort-on-error en installer** | ✅ Resuelto | Macro `ExecPowerShell` aborda el code path de error con `Abort` |
| **NSSM log expone argumentos sensibles** | ✅ Mejorado | `Invoke-NssmCommand` oculta argumentos cuando detecta `ObjectName` |
| **SPA rewrite interfiere con /api/** | ✅ Resuelto | Condición `{REQUEST_URI}` con `pattern="^/api/"` negate en regla Angular SPA |
| **AppPool previo no se limpiaba** | ✅ Resuelto | `setup-iis-site.ps1` ahora elimina AppPool previo antes de crear uno nuevo |
| **MIME map duplicado webmanifest** | ✅ Resuelto | `web.config` ahora hace `remove` antes de `mimeMap` |

---

## 3. Análisis de Paridad — Legacy vs. Nuevo

### Controles de Seguridad

| Aspecto | Legacy | Nuevo | ¿Paridad? |
|---------|--------|-------|-----------|
| **Autenticación** | Forms Auth `requireSSL=true`, `protection=All` | JWT cookie HttpOnly, `Secure` condicional | ⚠️ Legacy siempre fuerza SSL; nuevo condiciona a `NODE_ENV` |
| **Validación AD** | Módulo `TSDomainFormsAuthentication` (Kerberos/NTLM) | LDAP bind manual sin TLS validation | ⚠️ LDAP funcional pero menos seguro que Kerberos |
| **HTTP→HTTPS** | Configurado a nivel IIS nativo | ✅ **Ahora** en `web.config` vía URL Rewrite | ✅ Paridad |
| **Session timeout** | Public=20min, Private=240min | Cookie `max_age` 20/240min + JWT `exp` | ✅ Consistente |
| **Anti-XSS** | `AntiXssEncoder` en ASP.NET | Pydantic + Angular template sanitization | ✅ Equivalente |
| **Version headers** | `enableVersionHeader=false`, `X-Powered-By` removido | FastAPI no expone version headers | ✅ Consistente |
| **RDP auth-required** | `<deny users="?" />` en `<location path="rdp">` | `Depends(authenticate)` en `/api/launch/{alias}` | ✅ Consistente |
| **HSTS** | IIS nativo (si configurado) | ❌ No configurado | 🔴 Pendiente |
| **GatewayCredentialsSource** | `value="4"` (Ask me later) | `value=0` (User Password) | ⚠️ Cambio intencional? |

### Reglas de Negocio

| Funcionalidad | Legacy | Nuevo | Estado |
|--------------|--------|-------|--------|
| Catálogo RemoteApps filtrado por grupo | ✅ | ✅ | ✅ Paridad |
| Escritorios remotos | ✅ | Simulación ✅ / Real: `desktops: []` | ⚠️ Parcial |
| Generación archivos `.rdp` | ✅ | ✅ | ✅ Paridad |
| Redirección dispositivos | Configurable vía `Web.config` | Hardcoded en `rdp_service.py` | ⚠️ No configurable |
| Modo público/privado | ✅ | ✅ | ✅ Paridad |

---

## 4. Revisión de Despliegue (Actualizada)

### `installer.nsi` — Mejoras detectadas

| Aspecto | v1 | v2 (Actual) |
|---------|-----|-------------|
| Manejo de errores PS | Pop sin validar | ✅ Macro `ExecPowerShell` con `Abort` |
| Ejecución desinstalación | Inline | ✅ Macro `ExecPowerShellQuiet` |
| Variables no usadas | `LblCredUser`, `TxtCredPass`, `ValCredPass` | ✅ Removidas |
| Página AD | Inline con `Goto` loops | ✅ `PageADShow` callback + `${For}/${Next}` |

### Scripts PowerShell — Mejoras detectadas

| Aspecto | v1 | v2 (Actual) |
|---------|-----|-------------|
| Parámetros | `param(...)` simple | ✅ `[CmdletBinding()]` + `Validate*` |
| Credenciales | `$PlainPass` todo el script | ✅ `SecureString` + limpieza `finally` |
| Documentación | Comentarios breves | ✅ `.SYNOPSIS/.DESCRIPTION/.EXAMPLE` |
| NSSM wrapper | Función simple | ✅ `Invoke-NssmCommand` con arg masking |
| Cert thumbprint | Sin validación | ✅ `ValidatePattern('^[a-fA-F0-9]{40}$')` |
| IIS restart | `iisreset /noforce` | ✅ `Restart-Service W3SVC, WAS` + fallback |

### Puntos pendientes en despliegue

| Aspecto | Estado | Detalle |
|---------|--------|---------|
| `.env` permisos en disco | ⚠️ | Credenciales en texto plano. Agregar ACL restrictivo post-instalación |
| JWT secret PRNG | ⚠️ | VBScript `Rnd()`. Migrar a `[System.Security.Cryptography.RandomNumberGenerator]` |
| Log rotation NSSM | ⚠️ | `setup-backend-service.ps1` v2 tiene `AppRotateFiles`/`AppRotateBytes` **comentado** (`# ... demás configuración de logs`). Verificar que se aplica |

---

## 5. Checklist de Mitigación Pre-Producción

### 🔴 Obligatorios

- [ ] **C1** — LDAP TLS: cambiar `Tls(validate=0)` a `Tls(validate=ssl.CERT_REQUIRED, ca_certs_file=...)` o usar `ldaps://`
- [ ] **C2** — Rate limiting: implementar `slowapi` (5 intentos/min por IP) en `/api/auth/login`
- [ ] **C4** — Headers en `web.config`:
  ```xml
  <add name="Strict-Transport-Security" value="max-age=31536000; includeSubDomains" />
  <add name="Content-Security-Policy" value="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'" />
  <add name="Referrer-Policy" value="strict-origin-when-cross-origin" />
  <add name="Permissions-Policy" value="camera=(), microphone=(), geolocation=()" />
  ```
- [ ] **C5** — CORS: configurar dinámicamente desde `.env` o eliminar middleware si se usa exclusivamente same-origin via IIS reverse proxy

### 🟡 Altamente Recomendados

- [ ] **A1** — Restringir ACLs del `.env` a la cuenta de servicio
- [ ] **A2** — Login campos faltantes: devolver `HTTP 400` con `HTTPException`
- [ ] **A3** — Health: remover `rdcbServer` y `simulationMode` del output
- [ ] **A6** — LDAP timeout: agregar `receive_timeout=10` a conexiones
- [ ] **C3** — Sanitizar `config.RDCB_SERVER` para PowerShell injection
- [ ] **C6** — JWT secret: reemplazar VBScript por PowerShell CSPRNG
- [ ] Verificar que log rotation NSSM (AppRotateFiles/AppRotateBytes) esté activo en el script refactorizado

### 🟢 Opcionales

- [ ] Evaluar `SameSite=Strict` para la cookie
- [ ] Logging JSON para SIEM
- [ ] Implementar escritorios remotos en modo real (`desktops: []`)
- [ ] Hacer configurable la redirección de dispositivos RDP

---

> [!IMPORTANT]
> **C1** (LDAP TLS) y **C2** (Rate Limiting) son los riesgos de mayor impacto real. Los cambios en scripts y web.config resolvieron correctamente varios hallazgos del reporte anterior, especialmente la seguridad de credenciales en los scripts y la redirección HTTPS.

> [!TIP]
> La refactorización de los scripts PowerShell es de alta calidad: `CmdletBinding`, `SecureString`, validaciones estrictas, documentación `.SYNOPSIS`, y funciones reutilizables. La macro `ExecPowerShell` en el installer con abort-on-error también es una mejora importante que previene instalaciones parciales silenciosas.
