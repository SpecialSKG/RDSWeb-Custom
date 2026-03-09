require('dotenv').config();

function toInt(value, fallback) {
    const parsed = Number.parseInt(value, 10);
    return Number.isNaN(parsed) ? fallback : parsed;
}

module.exports = {
    port: Number.parseInt(process.env.PORT, 10) || 3000,
    nodeEnv: process.env.NODE_ENV || 'development',

    jwt: {
        secret: process.env.JWT_SECRET || 'dev_secret_insecure_change_in_production',
        expiresIn: process.env.JWT_EXPIRES_IN || '8h',
    },

    ldap: {
        url: process.env.LDAP_URL || 'ldap://dc01.lab-mh.local',
        baseDn: process.env.LDAP_BASE_DN || 'DC=lab-mh,DC=local',
        domain: process.env.AD_DOMAIN || 'LAB-MH',
        // Cuenta de servicio (solo lectura en AD) para hacer búsquedas LDAP
        // Formato recomendado: usuario@dominio.local  o  CN=svc-rdweb,OU=Servicios,DC=lab-mh,DC=local
        serviceUserDn: process.env.AD_SERVICE_USER || 'svc-rdweb@lab-mh.local',
        servicePass: process.env.AD_SERVICE_PASS || '',
    },

    rdcb: {
        server: process.env.RDCB_SERVER || 'SRV-APPS.LAB-MH.LOCAL',
    },

    rdp: {
        gatewayCredentialsSource: toInt(process.env.RDP_GATEWAY_CREDENTIAL_SOURCE, 0),
        promptCredentialOnce: process.env.RDP_PROMPT_CREDENTIAL_ONCE !== 'false',
        promptForCredentialsOnClient: process.env.RDP_PROMPT_FOR_CREDENTIALS_ON_CLIENT !== 'false',
        useMultimon: process.env.RDP_USE_MULTIMON === 'true',
        spanMonitors: process.env.RDP_SPAN_MONITORS === 'true',
    },

    simulation: {
        enabled: process.env.SIMULATION_MODE === 'true',
    },
};
