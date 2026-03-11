// 0. Función para inyectar el preloader de video de forma segura
function injectPreloader() {
    if (!document.getElementById('video-preloader') && document.body) {
        const preloader = document.createElement('div');
        preloader.id = 'video-preloader';
        preloader.innerHTML = `<video id="preloader-vid" src="../preloader.mp4" autoplay loop muted playsinline></video>`;
        document.body.appendChild(preloader);
    }
}

// Ejecutar inmediatamente si el body existe, o al cargar
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectPreloader);
} else {
    injectPreloader();
}

document.addEventListener('DOMContentLoaded', () => {
    // Ejecutar inyector preloader por si acaso
    injectPreloader();

    // Detectamos en qué página estamos buscando elementos clave
    const loginForm = document.getElementById('FrmLogin');

    // El contenedor de aplicaciones se genera posteriormente en Default.aspx
    // Esperaremos a que se cargue

    if (loginForm) {
        initLoginInjection();
    } else {
        initDashboardInjection();
    }
});

function initLoginInjection() {
    // 1. Ocultamos las tablas base viejas que abarcan toda la pantalla,
    // pero dejamos la estructura nativa en el DOM para poder enviar el formulario.
    const mainTables = document.querySelectorAll('body > table');
    mainTables.forEach(t => t.style.display = 'none');

    // Leemos cualquier error que haya arrojado IIS en la validación anterior
    let errorMsg = '';
    const errTrs = document.querySelectorAll('tr[id^="trError"]');
    errTrs.forEach(tr => {
        if (tr.style.display !== 'none') {
            const span = tr.querySelector('span.wrng');
            if (span) errorMsg += span.innerText + ' ';
        }
    });

    // 2. Construimos nuestra estructura moderna en el body
    const wrapper = document.createElement('div');
    wrapper.className = 'background-wrapper';
    wrapper.innerHTML = `
        <div class="glow glow-1"></div>
        <div class="glow glow-2"></div>
        <div class="glow glow-3"></div>
    `;
    document.body.appendChild(wrapper);

    const appContainer = document.createElement('div');
    appContainer.className = 'app-container';

    // Obtenemos el nombre del Workspace si está disponible en la página nativa
    let workspaceName = document.querySelector('input[name="WorkspaceFriendlyName"]')?.value || 'Recursos de Trabajo';

    appContainer.innerHTML = `
        <div id="login-view" class="view active">
            <div class="login-card glass-card">
                <div class="login-header">
                    <div style="margin-bottom: 2rem; display: flex; justify-content: center;">
                        <img src="logo.png" alt="Ministerio de Hacienda" style="width: 300px; height: 200px; object-fit: contain;">
                    </div>
                    <h2>Portal Web Apps MH</h2>
                    <p>Acceso seguro DINAFI - USC</p>
                </div>
                ${errorMsg ? `<div style="color: #ef4444; font-size: 0.85rem; text-align: center; margin-bottom: 1rem; background: rgba(239, 68, 68, 0.1); padding: 0.5rem; border-radius: 8px;">${errorMsg}</div>` : ''}
                <form id="modern-login-form">
                    <div class="input-group">
                        <label>Usuario (Dominio\\Usuario)</label>
                        <div class="input-wrapper">
                            <input type="text" id="modern-username" placeholder="dominio\\usuario" required autocomplete="off">
                            <i style="font-style:normal;">👤</i>
                        </div>
                    </div>
                    <div class="input-group">
                        <label>Contraseña</label>
                        <div class="input-wrapper">
                            <input type="password" id="modern-password" placeholder="••••••••" required autocomplete="off">
                            <i style="font-style:normal;">🔒</i>
                        </div>
                    </div>
                    <div class="options-group" style="display:none;">
                        <!-- Ocultamos la opción privado/público nativa para simplificar, o la forzamos a privado por seguridad -->
                        <label class="checkbox-container">
                            <input type="checkbox" id="modern-private" checked> Equipo Privado
                        </label>
                    </div>
                    <button type="submit" id="modern-btn-login" class="btn-primary">
                        <span class="btn-text">Ingresar</span>
                        <div class="loader-spinner" style="display: none;"></div>
                    </button>
                    <div class="security-note">
                        <span style="font-size: 16px;">🛡️</span> Conexión Cifrada SSL
                    </div>
                </form>
            </div>
        </div>
    `;
    document.body.appendChild(appContainer);

    // 3. Vincular los eventos de nuestro form moderno al viejo form oculto
    const modernForm = document.getElementById('modern-login-form');
    modernForm.addEventListener('submit', (e) => {
        e.preventDefault();

        // Copiamos los campos de texto
        document.getElementById('DomainUserName').value = document.getElementById('modern-username').value;
        document.getElementById('UserPass').value = document.getElementById('modern-password').value;

        // Manejamos los Radios de Privado/Publico que IIS usa
        const isPrivate = document.getElementById('modern-private').checked;
        const rdoPrvt = document.getElementById('rdoPrvt');
        const rdoPblc = document.getElementById('rdoPblc');
        if (rdoPrvt && rdoPblc) {
            rdoPrvt.checked = isPrivate;
            rdoPblc.checked = !isPrivate;
            // IIS exige que se invoque este script nativo si se cambian
            if (typeof onClickSecurity === "function") onClickSecurity();
        }

        // Mostrar estado de carga (feedback visual)
        const btnLogin = document.getElementById('modern-btn-login');
        btnLogin.querySelector('.btn-text').style.display = 'none';
        btnLogin.querySelector('.loader-spinner').style.display = 'block';
        btnLogin.style.pointerEvents = 'none';

        // Hacer click en el botón real para enviar (eso hace que pase por las validaciones de IIS)
        const realBtn = document.getElementById('btnSignIn');
        if (realBtn) {
            realBtn.click();
        } else {
            document.getElementById('FrmLogin').submit();
        }
    });

    // Ocultar preloader de video después del inicio de sesión
    setTimeout(() => {
        const pl = document.getElementById('video-preloader');
        if (pl) pl.classList.add('hidden');
    }, 1500); // 1.5s para apreciar la animación
}


function initDashboardInjection() {
    // 1. Ocultar la tabla base enorme de Site.xsl
    const mainTables = document.querySelectorAll('body > table');
    mainTables.forEach(t => t.style.display = 'none');

    // Default.aspx usa solicitudes HTTP para popular las apps con la función ParseXML
    // Hacemos un pequeño loop para esperar a que las apps (.tswa_boss) sean inyectadas en el DOM nativamente
    const waitTime = 100; // ms
    let retries = 50; // max 5 seconds

    const checkForApps = setInterval(() => {
        const pleaseWait = document.querySelector('[id$="PleaseWait"]');

        // Si aún está dibujado el cartel de "Searching for apps..." o similar por parte de IIS, esperamos.
        if (pleaseWait && pleaseWait.style.display !== 'none') {
            retries--;
            if (retries <= 0) {
                clearInterval(checkForApps);
                renderModernDashboard(); // Renderizamos lo que haya o un error
            }
            return;
        }

        // Estructuras cargadas!
        clearInterval(checkForApps);
        renderModernDashboard();
    }, waitTime);
}

function renderModernDashboard() {
    // Buscamos todas las apps y carpetas del layout viejo
    const oldApps = document.querySelectorAll('.tswa_boss');
    const oldFolders = document.querySelectorAll('.tswa_folder_boss, .tswa_up_boss');

    // Obtenemos el nombre del usuario de la sesión actual (o nombre completo si se inyectó)
    let fullname = document.getElementById('DomainFullName')?.value || '';
    let username = document.getElementById('DomainUserName')?.value || '';

    // Preferimos el Nombre Completo (DisplayName) de AD si C# lo trajo con éxito
    if (fullname && fullname.trim() !== '' && !fullname.includes('\\')) {
        username = fullname.trim();
    } else {
        // Fallback al nombre de login corto clásico de IIS
        if (username.includes('\\')) username = username.split('\\')[1];
        if (!username) username = "Usuario";
        username = username.charAt(0).toUpperCase() + username.slice(1);
    }

    // 2. Construimos nuestra vista Glassmorphism
    const wrapper = document.createElement('div');
    wrapper.className = 'background-wrapper';
    wrapper.innerHTML = `
        <div class="glow glow-1"></div>
        <div class="glow glow-2"></div>
        <div class="glow glow-3"></div>
    `;
    document.body.appendChild(wrapper);

    const appContainer = document.createElement('div');
    appContainer.className = 'app-container';

    let html = `
        <div id="dashboard-view" class="view active">
            <div class="dashboard-header">
                <div class="header-left">
                    <div style="margin-right: 1.5rem; display: flex; align-items: center;">
                        <img src="logo.png" alt="Ministerio de Hacienda" style="width: 300px; height: 200px; object-fit: contain;">
                    </div>
                    <div>
                        <h1>RDS WEB APPS MH</h1>
                        <p>Haz clic en el icono para conectarte</p>
                    </div>
                </div>
                <div class="header-right">
                    <div class="user-profile">
                        <div class="avatar">${username.charAt(0)}</div>
                        <div class="user-info">
                            <span class="user-name">${username}</span>
                            <span class="user-role">Conectado a AD</span>
                        </div>
                    </div>
                    <!-- Logout icon -->
                    <button class="btn-icon" id="modern-logout" title="Cerrar Sesión">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
                    </button>
                </div>
            </div>
            <div class="apps-grid" id="modern-apps-grid">
    `;

    // Procesamos Carpetas si las hay
    oldFolders.forEach((folder, idx) => {
        const title = folder.getAttribute('title') || 'Carpeta';

        html += `
            <a class="app-card" href="javascript:void(0)" onclick="executeOldFunction(event, \`old-folder-\${idx}\`)">
                <div class="app-icon-wrapper" style="background: rgba(255,193,7,0.2); color: #FFC107;">
                    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
                </div>
                <div class="app-name">${title}</div>
            </a>
        `;
        folder.id = `old-folder-${idx}`;
    });

    // Validamos si efectivamente recibimos las apps
    if (oldApps.length === 0 && oldFolders.length === 0) {
        html += `<div style="grid-column: 1/-1; text-align: center; color: var(--text-muted); padding: 3rem;">No cuentas con aplicaciones públicas o no se cargaron correctamente.</div>`;
    }

    // Procesamos RemoteApps
    oldApps.forEach((app, idx) => {
        const nameNode = app.querySelector('.tswa_ttext');
        const imgNode = app.querySelector('.tswa_iconimg');

        const appName = nameNode ? nameNode.innerText.trim() : 'App';
        const iconSrc = imgNode ? imgNode.src : '';

        // Determinamos un themeClass basado en el nombre para dar el fondo estilizado
        let themeClass = '';
        const lowerName = appName.toLowerCase();
        if (lowerName.includes('word')) themeClass = 'word-theme';
        else if (lowerName.includes('excel')) themeClass = 'excel-theme';
        else if (lowerName.includes('powerpoint')) themeClass = 'powerpoint-theme';
        else if (lowerName.includes('outlook')) themeClass = 'outlook-theme';
        else if (lowerName.includes('escritorio') || lowerName.includes('desktop')) themeClass = 'desktop-theme';
        else themeClass = 'desktop-theme';

        // Identificamos el viejo nodo para clickearlo programáticamente
        app.id = `old-app-${idx}`;

        html += `
            <a class="app-card" href="javascript:void(0)" onclick="executeOldFunction(event, 'old-app-${idx}')">
                <div class="app-icon-wrapper ${themeClass}">
                    ${iconSrc
                ? `<img src="${iconSrc}" style="width: 48px; height: 48px; object-fit: contain; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.5));" />`
                : `<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>`}
                </div>
                <div class="app-name">${appName}</div>
                <div class="app-publisher">Extensión RDS</div>
            </a>
        `;
    });

    html += `
            </div>
            <div class="dashboard-footer">
                RDS Web Access Seguro • DINAFI - USC
            </div>
        </div>
    `;

    appContainer.innerHTML = html;
    document.body.appendChild(appContainer);

    // Vinculamos el botón de cerrar sesión
    document.getElementById('modern-logout').addEventListener('click', () => {
        // En Default.aspx o Site.xsl el logout real suele estar en el enlace de la barra antigua
        const origLogout = document.getElementById('PORTAL_SIGNOUT');
        if (origLogout) {
            origLogout.click(); // Ejecuta el click nativo
        } else {
            // Fallback usando las funciones globales generadas por Microsoft
            if (typeof onUserDisconnect === "function") {
                onUserDisconnect();
            } else {
                window.location.href = '../login.aspx';
            }
        }
    });

    // Ocultamos el preloader de VIDEO una vez que las apps están listas
    setTimeout(() => {
        const pl = document.getElementById('video-preloader');
        if (pl) pl.classList.add('hidden');
    }, 1500); // Darle tiempo (1.5s) al usuario para que vea la intro animada
}

// Global para ejecutar las viejas funciones
// Al inyectar el diseño, no queremos perder los RDP generados dinámicamente con tokens validos de ActiveDirectory.
// Para no recrear la magia de IIS, simplemente evaluamos ("clicamos virtualmente") la lógica vieja y transparente.
window.executeOldFunction = function (e, elementId) {
    e.preventDefault();
    const el = document.getElementById(elementId);
    if (el) {
        // Extraemos la ejecución de onmouseup que tiene pre-cargada el RDP
        const mouseUpAttr = el.getAttribute('onmouseup');
        if (mouseUpAttr) {
            // Con new Function aseguramos que "this" dentro de la ejecución se refiera a "el" (el cuadro viejo)
            const func = new Function(mouseUpAttr);
            func.call(el);
        } else {
            el.click(); // Fallback si estuviera en onclick
        }
    }
}
