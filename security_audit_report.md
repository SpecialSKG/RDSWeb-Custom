# 🔒 Auditoría de Seguridad y Paridad Funcional — RDS Web Portal

**Fecha:** 2026-03-16  
**Alcance:** `/backend-py`, `/frontend`, `/rd-web-antiguo`, `installer.nsi`, `/scripts`

---

## 1. Riesgos Críticos Encontrados

### 🔴 CRÍTICO — Hallazgos que DEBEN resolverse antes de producción

| # | Componente | Vulnerabilidad | OWASP | Detalle |
|---|-----------|---------------|-------|---------|
| C1 | `backend-py` | **TLS no validado en LDAP** | A07:2021 | [ad_service.py:130](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/services/ad_service.py#L130) usa `Tls(validate=0)`, deshabilitando toda validación de certificados. Un atacante en la red podría hacer MITM al tráfico LDAP e interceptar credenciales en texto plano. |
| C2 | `backend-py` | **Falta Rate Limiting en login** | A07:2021 | [auth.py:34](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/routers/auth.py#L34) — El endpoint `POST /api/auth/login` no tiene protección contra fuerza bruta. Sin limitación de intentos, un atacante puede probar miles de credenciales por segundo. |
| C3 | `backend-py` | **Ejecución de PowerShell sin validación** | A03:2021 | [rdcb_service.py:142](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/services/rdcb_service.py#L142) — El valor `config.RDCB_SERVER` se interpola directamente en el script PowerShell con `f-string`. Si el valor de `.env` fuera manipulado, permitiría **Command Injection**. Aunque hoy viene del `.env`, es una superficie de ataque si el archivo es comprometido. |
| C4 | `frontend` | **Faltan headers de seguridad críticos** | A05:2021 | [web.config](file:///c:/DevTools/Proyectos/RDSWeb-Custom/frontend/web.config#L34-L39) solo tiene `X-Content-Type-Options` y `X-Frame-Options`. **Faltan**: `Strict-Transport-Security (HSTS)`, `Content-Security-Policy (CSP)`, `Referrer-Policy`, `Permissions-Policy`. |
| C5 | `backend-py` | **CORS hardcoded a localhost** | A05:2021 | [main.py:44](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/main.py#L44) — CORS permite solo `localhost:4200` y `localhost:4300`. En producción debe aceptar el dominio real del frontend o, como se usa reverse proxy, **omitir CORS y confiar en same-origin**. |
| C6 | `installer` | **JWT Secret de baja entropía** | A02:2021 | [installer.nsi:376](file:///c:/DevTools/Proyectos/RDSWeb-Custom/installer.nsi#L376) genera un secreto JWT con VBScript de solo **32 caracteres hex (128 bits)**. Aunque es aceptable, el script es un VBScript con `Rnd()` cuyo PRNG no es criptográficamente seguro. |

---

### 🟡 ALTO — Hallazgos importantes que deberían resolverse

| # | Componente | Vulnerabilidad | Detalle |
|---|-----------|---------------|---------|
| A1 | `backend-py` | **Credenciales AD en `.env` en texto plano** | [config.py:63-64](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/core/config.py#L63-L64) — `AD_SERVICE_USER` y `AD_SERVICE_PASS` se almacenan en texto plano en el `.env`. No hay cifrado ni uso de un vault de credenciales. |
| A2 | `backend-py` | **Login devuelve HTTP 200 con error en body** | [auth.py:37](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/routers/auth.py#L37) — Cuando faltan campos, se devuelve `200 OK` con `{"error": ...}` en el body en vez de un `400 Bad Request`. Esto puede confundir herramientas de monitoreo. |
| A3 | `backend-py` | **Health endpoint expone configuración interna** | [main.py:56-61](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/main.py#L56-L61) — `/api/health` expone `simulationMode`, `rdcbServer` y timestamp sin autenticación. Un atacante puede inferir la infraestructura interna. |
| A4 | `backend-py` | **Grupos AD almacenados en JWT** | [auth.py:55](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/routers/auth.py#L55) — La lista completa de grupos AD se incluye en el payload del JWT. Si el token se extrae, revela toda la estructura de grupos del usuario. Además, los permisos no se re-evalúan hasta que el token expire. |
| A5 | `backend-py` | **`docs_url` expuesto en no-producción** | [main.py:37](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/main.py#L37) — `/api/docs` se deshabilita solo si `NODE_ENV == "production"`. Si la variable se configura mal, Swagger queda expuesto. |
| A6 | `backend-py` | **Sin timeout en LDAP bind** | [ad_service.py:135-142](file:///c:/DevTools/Proyectos/RDSWeb-Custom/backend-py/app/services/ad_service.py#L135-L142) — Las conexiones LDAP (`Connection` de `ldap3`) no especifican `receive_timeout`, pudiendo colgar indefinidamente si el DC no responde. |
| A7 | `installer` | **Contraseña escrita a archivo temporal** | [installer.nsi:408-410](file:///c:/DevTools/Proyectos/RDSWeb-Custom/installer.nsi#L408-L410) — La contraseña AD se escribe a `$TEMP\svcpwd.dat`. Aunque se elimina después (línea 418), podría recuperarse con herramientas forenses si el disco no se sanitiza. |

---

### 🟢 BAJO — Mejoras recomendadas

| # | Componente | Observación |
|---|-----------|------------|
| B1 | `backend-py` | Cookie `SameSite=Lax` es correcto, pero considerar `Strict` si no se requiere navegación cross-site. |
| B2 | `frontend` | [apps.service.ts:34-39](file:///c:/DevTools/Proyectos/RDSWeb-Custom/frontend/src/app/core/services/apps.service.ts#L34-L39) — La descarga del `.rdp` usa `<a href>` + click programático. La cookie HttpOnly **no se enviará** automáticamente en la descarga si el navegador la trata como navegación cross-origin. Funciona correctamente solo bajo same-origin (IIS reverse proxy). |
| B3 | `backend-py` | No hay logging estructurado (JSON). Dificultará integración con SIEM. |
| B4 | `scripts` | [setup-backend-service.ps1:141](file:///c:/DevTools/Proyectos/RDSWeb-Custom/scripts/setup-backend-service.ps1#L141) — La contraseña se pasa como argumento a `nssm set ObjectName`. Los argumentos de proceso son visibles en el sistema. |

---

## 2. Análisis de Paridad — Legacy (ASP.NET) vs. Nuevo (Angular + Python)

### Controles de Seguridad Comparados

| Aspecto | Legacy (`rd-web-antiguo`) | Nuevo (`backend-py` + `frontend`) | ¿Paridad? |
|---------|--------------------------|----------------------------------|-----------|
| **Autenticación** | Forms Auth ASP.NET con cookie `TSWAAuthHttpOnlyCookie`, `requireSSL=true`, `protection=All` | JWT en cookie `rdweb_token` HttpOnly, `Secure` condicional, `SameSite=Lax` | ⚠️ Parcial — Legacy siempre forzaba `requireSSL`; el nuevo lo condiciona a `NODE_ENV` |
| **Validación contra AD** | Windows Forms Auth con módulo `TSDomainFormsAuthentication` (integrado en IIS, validación Kerberos/NTLM) | Bind LDAP manual con `ldap3`, sin validación TLS | ⚠️ Parcial — La validación LDAP es funcional pero menos segura que Kerberos |
| **Timeout de sesión** | `PublicModeSessionTimeoutInMinutes=20`, `PrivateModeSessionTimeoutInMinutes=240` | `timeout_minutes = 240 if privateMode else 20` (cookie `max_age`), JWT `exp` vía `JWT_EXPIRES_IN` | ✅ Consistente |
| **Protección anti-XSS** | `AntiXssEncoder` habilitado en ASP.NET `httpRuntime` | Pydantic para validación de entrada, Angular sanitiza templates por defecto | ✅ Equivalente |
| **Version header** | `enableVersionHeader="false"`, `X-Powered-By` removido | FastAPI no expone headers de versión por defecto | ✅ Consistente |
| **Acceso a RDP** | `<deny users="?" />` en `<location path="rdp">` (requiere autenticación) | Route `/api/launch/{alias}` protegido por `Depends(authenticate)` | ✅ Consistente |
| **Filtro de apps por grupo** | Nativo vía `Get-RDRemoteApp` con `UserGroups` + RD Connection Broker filtra por ACL | PowerShell `Get-RDRemoteApp` + filtrado manual por grupos en Python | ✅ Lógica replicada |
| **HSTS / HTTP→HTTPS** | Configurado a nivel IIS nativo | ❌ No configurado en el nuevo `web.config` ni en el backend | 🔴 Regresión |
| **Cambio de contraseña** | `PasswordChangeEnabled=false` (disponible como opción) | No implementado | ✅ No era funcionalidad activa |
| **GatewayCredentialsSource** | `value="4"` (Ask me later) | `RDP_GATEWAY_CREDENTIAL_SOURCE=0` (User Password) | ⚠️ Diferente — Puede ser intencional |

### Reglas de Negocio Comparadas

| Funcionalidad | Legacy | Nuevo | Estado |
|--------------|--------|-------|--------|
| Login con usuario/contraseña de dominio | ✅ | ✅ | ✅ Paridad |
| Catálogo de RemoteApps filtrado por grupo | ✅ (RD Connection Broker nativo) | ✅ (PowerShell + filtrado Python) | ✅ Paridad |
| Escritorios remotos | ✅ (`ShowDesktops=true`) | ✅ (solo en modo simulación actualmente) | ⚠️ En modo real, `get_apps_for_user` retorna `desktops: []` |
| Generación de archivos `.rdp` | ✅ (ASP.NET handler `ResourceFileHandler`) | ✅ (`rdp_service.py`) | ✅ Paridad |
| Redirección de dispositivos (impresoras, clipboard, drives) | Configurable vía `Web.config` | Hardcoded en `rdp_service.py` | ⚠️ Diferente — Legacy era configurable, nuevo es fijo |
| Modo público/privado | ✅ (timeouts distintos) | ✅ (timeouts distintos en cookie) | ✅ Paridad |

---

## 3. Revisión de Despliegue (Installer + Scripts)

### `installer.nsi`

| Aspecto | Estado | Detalle |
|---------|--------|---------|
| Ejecución como admin | ✅ | `RequestExecutionLevel admin` |
| Generación de JWT Secret | ⚠️ | Usa VBScript `Rnd()` (no criptográfico). Mejorar con `[System.Security.Cryptography.RandomNumberGenerator]` en PowerShell |
| Contraseña AD en disco | ⚠️ | Escrita a `$TEMP\svcpwd.dat`, eliminada después. Usar SecureString o pipe |
| Directorio de instalación | ✅ | `C:\inetpub\wwwroot` (estándar IIS) |
| `.env` generado en instalación | ✅ | Credenciales configuradas por el instalador, no hardcodeadas |
| Limpieza en desinstalación | ✅ | Scripts de uninstall limpian servicio, sitio IIS, y registro |

### `scripts/setup-backend-service.ps1`

| Aspecto | Estado | Detalle |
|---------|--------|---------|
| Validación de credenciales AD | ✅ | Usa `PrincipalContext.ValidateCredentials` antes de configurar NSSM |
| Limpieza de contraseña en memoria | ⚠️ | `$PlainPass = $null` + `GC.Collect()` — No garantiza limpieza por comportamiento de .NET GC |
| Servicio corre como cuenta AD | ✅ | NSSM configura `ObjectName` con la cuenta de servicio |
| Log rotation | ✅ | NSSM configurado con `AppRotateFiles` y `AppRotateBytes=5MB` |

### `scripts/setup-iis-site.ps1`

| Aspecto | Estado | Detalle |
|---------|--------|---------|
| HTTPS con certificado seleccionado | ✅ | Binding HTTPS con thumbprint |
| HTTP binding para redirect | ✅ | Puerto 80 agregado para redirect a HTTPS |
| Application Pool como `ApplicationPoolIdentity` | ✅ | Principio de menor privilegio |
| No Managed Code | ✅ | `managedRuntimeVersion = ""` (correcto para archivos estáticos) |

### Permisos de carpetas

| Aspecto | Estado | Detalle |
|---------|--------|---------|
| Frontend en `$INSTDIR\frontend` | ✅ | Solo lectura para IIS si `ApplicationPoolIdentity` |
| Backend en `$INSTDIR\backend` | ⚠️ | El `.env` con credenciales está en la misma carpeta que el ejecutable. Debería tener ACL restrictivo |
| Logs en `$INSTDIR\backend\logs` | ✅ | Carpeta creada con permisos heredados |

---

## 4. Checklist de Mitigación Pre-Producción

### 🔴 Obligatorios (Bloquean paso a producción)

- [ ] **C1** — Habilitar validación TLS en LDAP: cambiar `Tls(validate=0)` a `Tls(validate=ssl.CERT_REQUIRED, ca_certs_file=...)` o usar `ldaps://` con certificado de CA válido
- [ ] **C2** — Implementar rate limiting en `/api/auth/login` (ej: `slowapi` con límite de 5 intentos/min por IP)
- [ ] **C4** — Agregar headers de seguridad al `web.config` del frontend:
  ```xml
  <add name="Strict-Transport-Security" value="max-age=31536000; includeSubDomains" />
  <add name="Content-Security-Policy" value="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'" />
  <add name="Referrer-Policy" value="strict-origin-when-cross-origin" />
  <add name="Permissions-Policy" value="camera=(), microphone=(), geolocation=()" />
  ```
- [ ] **C5** — Corregir CORS: en producción (detrás de IIS reverse proxy) el frontend y backend comparten origen. Configurar CORS dinámicamente desde `.env` o eliminarlo si se usa same-origin exclusivo

### 🟡 Altamente recomendados

- [ ] **A1** — Restringir ACLs del archivo `.env` a solo la cuenta de servicio y administradores
- [ ] **A2** — Cambiar respuesta de campos faltantes en login a `HTTP 400` con `HTTPException`
- [ ] **A3** — Proteger `/api/health` eliminando `rdcbServer` y `simulationMode` del output, o ponerlo detrás de autenticación
- [ ] **A4** — Considerar re-evaluar grupos AD en cada request en lugar de confiar en el JWT (trade-off rendimiento vs. seguridad)
- [ ] **A6** — Agregar `receive_timeout=10` a las conexiones LDAP
- [ ] **C3** — Sanitizar `config.RDCB_SERVER` o usar parametrización segura al construir el script PowerShell
- [ ] **C6** — Mejorar generación de JWT secret en el instalador usando `[System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)` desde PowerShell

### 🟢 Mejoras opcionales

- [ ] **B1** — Evaluar `SameSite=Strict` para la cookie si el flujo lo permite
- [ ] **B3** — Implementar logging JSON para integración con SIEM
- [ ] **B4** — Explorar alternativas a pasar contraseña como argumento a NSSM (ej: `stdin` pipe)
- [ ] Agregar escritorios remotos al modo real (actualmente retorna `desktops: []`)
- [ ] Hacer configurable la redirección de dispositivos RDP (como en el legacy)
- [ ] Alinear `GatewayCredentialsSource` con el valor original si no fue cambio intencional

---

> [!IMPORTANT]
> Los hallazgos C1 (TLS LDAP) y C2 (Rate Limiting) son los de mayor riesgo real. Un atacante en la red interna podría interceptar credenciales AD, y sin rate limiting el endpoint de login es vulnerable a ataques de fuerza bruta automatizados.

> [!TIP]
> La arquitectura nueva (Angular SPA + FastAPI + IIS reverse proxy) es sólida y moderna. La mayoría de hallazgos son configuraciones que se corrigen sin cambios arquitectónicos. La separación frontend/backend y el uso de cookies HttpOnly con JWT es un patrón de seguridad correcto.
