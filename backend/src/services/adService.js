const { authenticate } = require('ldap-authentication');
const config = require('../config');

// ── Datos simulados cuando SIMULATION_MODE=true ────────────────────────────────
const SIMULATED_USERS = [
    {
        username: 'administrador',
        password: 'Admin1234!',
        displayName: 'Administrador',
        email: 'admin@lab-mh.local',
        domain: 'LAB-MH',
        groups: ['RemoteApp Users', 'Domain Admins', 'Contabilidad', 'Desarrollo'],
    },
    {
        username: 'juan.perez',
        password: 'Usuario1234!',
        displayName: 'Juan Pérez',
        email: 'juan.perez@lab-mh.local',
        domain: 'LAB-MH',
        groups: ['RemoteApp Users', 'Contabilidad'],
    },
    {
        username: 'maria.garcia',
        password: 'Usuario1234!',
        displayName: 'María García',
        email: 'maria.garcia@lab-mh.local',
        domain: 'LAB-MH',
        groups: ['RemoteApp Users', 'Desarrollo'],
    },
    {
        username: 'carlos.lopez',
        password: 'Usuario1234!',
        displayName: 'Carlos López',
        email: 'carlos.lopez@lab-mh.local',
        domain: 'LAB-MH',
        groups: ['RemoteApp Users', 'RRHH'],
    },
    {
        username: 'demo',
        password: 'demo',
        displayName: 'Usuario Demo',
        email: 'demo@lab-mh.local',
        domain: 'LAB-MH',
        groups: ['RemoteApp Users'],
    },
];

// ── Helpers ────────────────────────────────────────────────────────────────────

/**
 * Normaliza el nombre de usuario — acepta varios formatos:
 *   DOMINIO\usuario  →  { domain: 'DOMINIO', cleanUser: 'usuario' }
 *   usuario@dominio  →  { domain: config, cleanUser: 'usuario' }
 *   usuario          →  { domain: config, cleanUser: 'usuario' }
 */
function parseUsername(username) {
    if (username.includes('\\')) {
        const [domain, cleanUser] = username.split('\\');
        return { domain: domain.toUpperCase(), cleanUser };
    }
    if (username.includes('@')) {
        const [cleanUser, domainSuffix] = username.split('@');
        return { domain: domainSuffix.split('.')[0].toUpperCase(), cleanUser };
    }
    return { domain: config.ldap.domain, cleanUser: username };
}

/**
 * Extrae la lista de nombres de grupos desde los atributos memberOf del objeto LDAP.
 * Soporta tanto string como array (AD según el número de grupos devuelve uno u otro).
 */
function extractGroups(memberOf) {
    if (!memberOf) return [];
    const arr = Array.isArray(memberOf) ? memberOf : [memberOf];
    return arr.map((dn) => dn.split(',')[0].replace(/^CN=/i, ''));
}

// ── Autenticación ──────────────────────────────────────────────────────────────

/**
 * Autentica un usuario contra Active Directory.
 *
 * En modo simulación valida contra datos locales.
 * En modo real usa ldap-authentication con una cuenta de servicio para buscar
 * los atributos del usuario (displayName, mail, memberOf) y luego verifica
 * las credenciales del usuario haciendo un bind adicional.
 *
 * Requiere en .env:
 *   LDAP_URL, LDAP_BASE_DN, AD_DOMAIN
 *   AD_SERVICE_USER  (ej: svc-rdweb@lab-mh.local)
 *   AD_SERVICE_PASS  (contraseña de la cuenta de servicio)
 *
 * @param {string} username  — acepta DOMINIO\user, user@dominio.local o solo user
 * @param {string} password
 * @returns {Promise<{ username, displayName, email, domain, groups }>}
 */
async function authenticateUser(username, password) {
    const { domain, cleanUser } = parseUsername(username);

    // ── MODO SIMULACIÓN ──────────────────────────────────────────────────────────
    if (config.simulation.enabled) {
        const found = SIMULATED_USERS.find(
            (u) => u.username.toLowerCase() === cleanUser.toLowerCase() && u.password === password
        );
        if (!found) {
            const err = new Error('Credenciales incorrectas');
            err.code = 'INVALID_CREDENTIALS';
            throw err;
        }
        return {
            username: found.username,
            displayName: found.displayName,
            email: found.email,
            domain: found.domain,
            groups: found.groups,
        };
    }

    // ── MODO REAL — Active Directory ─────────────────────────────────────────────
    //
    // ldap-authentication hace dos operaciones:
    //   1. Bind con la cuenta de servicio (AD_SERVICE_USER/PASS) para buscar el DN del usuario
    //   2. Bind con las credenciales del usuario para validarlas
    //
    // Esto es la práctica estándar en enterprise AD: la cuenta de servicio tiene
    // permisos de lectura en el directorio pero NO permisos elevados.

    const adOptions = {
        ldapOpts: {
            url: config.ldap.url,
            tlsOptions: { rejectUnauthorized: false }, // en prod: true + certificado CA
        },
        // Cuenta de servicio para búsqueda inicial
        adminDn: config.ldap.serviceUserDn,
        adminPassword: config.ldap.servicePass,
        // Búsqueda del usuario
        userSearchBase: config.ldap.baseDn,
        usernameAttribute: 'sAMAccountName',
        username: cleanUser,
        // Contraseña que se valida (bind como el usuario)
        userPassword: password,
        // Atributos a recuperar del usuario
        attributes: ['displayName', 'mail', 'memberOf', 'sAMAccountName', 'userPrincipalName'],
    };

    try {
        const user = await authenticate(adOptions);

        // `user` contiene los atributos LDAP del usuario si la auth fue exitosa
        const groups = extractGroups(user.memberOf);
        console.log(`[adService] Auth OK → usuario: ${user.sAMAccountName || cleanUser}, grupos (${groups.length}): [${groups.join(', ')}]`);
        return {
            username: user.sAMAccountName || cleanUser,
            displayName: user.displayName || cleanUser,
            email: user.mail || user.userPrincipalName || '',
            domain,
            groups,
        };
    } catch (err) {
        // ldap-authentication lanza un error con message '...' cuando las credenciales fallan
        const msg = err.message || '';
        if (
            msg.includes('INVALID_CREDENTIALS') ||
            msg.includes('InvalidCredentialsError') ||
            err.code === 49
        ) {
            const credErr = new Error('Credenciales incorrectas. Verifica tu usuario y contraseña.');
            credErr.code = 'INVALID_CREDENTIALS';
            throw credErr;
        }
        if (msg.includes('No such object') || msg.includes('NO_OBJECT')) {
            const notFoundErr = new Error('Usuario no encontrado en Active Directory.');
            notFoundErr.code = 'USER_NOT_FOUND';
            throw notFoundErr;
        }
        // Error de conectividad u otro problema de AD
        console.error('[adService] Error conectando a AD:', msg);
        const srvErr = new Error('No se pudo conectar al servidor de Active Directory.');
        srvErr.code = 'AD_UNREACHABLE';
        throw srvErr;
    }
}

module.exports = { authenticateUser };
