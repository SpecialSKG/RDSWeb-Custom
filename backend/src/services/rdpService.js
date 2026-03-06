const config = require('../config');

function normalizeCollectionName(collectionName = '') {
    return String(collectionName || '')
        .trim()
    .replaceAll(/\s+/g, '_')
    .replaceAll(/\W/g, '_')
        .toUpperCase();
}

/**
 * Genera el contenido de un archivo .rdp para una RemoteApp.
 *
 * @param {object} app    — objeto de la app { alias, name, rdpPath, remoteServer }
 * @param {object} user   — objeto del usuario { username, domain, displayName }
 * @param {boolean} isPrivate  — true = modo privado (sesión más larga)
 * @returns {string}  contenido del archivo .rdp
 */
function generateRemoteAppRdp(app, user, isPrivate = true) {
    const domain = user.domain || config.ldap.domain;
    const username = `${domain}\\${user.username}`;
    const sessionTimeout = isPrivate ? 240 : 20;
    const fullAddress = app.remoteServer || config.rdcb.server;
    const collectionName = normalizeCollectionName(app.collectionName);

    const lines = [
        'redirectclipboard:i:1',
        'redirectprinters:i:1',
        'redirectcomports:i:1',
        'redirectsmartcards:i:1',
        'devicestoredirect:s:*',
        'drivestoredirect:s:*',
        'redirectdrives:i:1',
        'session bpp:i:32',
        `prompt for credentials on client:i:${config.rdp.promptForCredentialsOnClient ? 1 : 0}`,
        `span monitors:i:${config.rdp.spanMonitors ? 1 : 0}`,
        `use multimon:i:${config.rdp.useMultimon ? 1 : 0}`,
        'remoteapplicationmode:i:1',
        'server port:i:3389',
        'allow font smoothing:i:1',
        `promptcredentialonce:i:${config.rdp.promptCredentialOnce ? 1 : 0}`,
        'gatewayusagemethod:i:1',
        'gatewayprofileusagemethod:i:1',
        `gatewaycredentialssource:i:${config.rdp.gatewayCredentialsSource}`,
        `full address:s:${fullAddress}`,
        `alternate shell:s:${app.rdpPath}`,
        `remoteapplicationprogram:s:${app.rdpPath}`,
        // gatewayhostname debe coincidir con el servidor que publica las apps (RDCB/RDSH)
        `gatewayhostname:s:${fullAddress}`,
        `remoteapplicationname:s:${app.name}`,
        'remoteapplicationcmdline:s:',
        `workspace id:s:${fullAddress}`,
        'use redirection server name:i:1',
    ];

    // loadbalanceinfo va antes de alternate full address (orden requerido por el cliente RDP)
    if (collectionName) {
        lines.push(`loadbalanceinfo:s:tsv://MS Terminal Services Plugin.1.${collectionName}`);
    }

    lines.push(`alternate full address:s:${fullAddress}`);

    return lines.join('\r\n');
}

/**
 * Genera el contenido de un archivo .rdp para un escritorio completo.
 *
 * @param {object} desktop  — objeto del escritorio { name, remoteServer }
 * @param {object} user     — objeto del usuario { username, domain }
 * @returns {string}
 */
function generateDesktopRdp(desktop, user) {
    const domain = user.domain || config.ldap.domain;
    const username = `${domain}\\${user.username}`;

    return [
        'screen mode id:i:2',
        'use multimon:i:0',
        'desktopwidth:i:1920',
        'desktopheight:i:1080',
        'session bpp:i:32',
        'compression:i:1',
        `full address:s:${desktop.remoteServer || config.rdcb.server}`,
        `gatewayhostname:s:${config.rdGateway.hostname}`,
        'gatewayusagemethod:i:1',
        'gatewaycredentialssource:i:4',
        'gatewayprofileusagemethod:i:1',
        `username:s:${username}`,
        'authentication level:i:3',
        'remoteapplicationmode:i:0',
        'redirectprinters:i:1',
        'redirectclipboard:i:1',
        'redirectdrives:i:0',
        'autoreconnection enabled:i:1',
    ].join('\r\n');
}

module.exports = {
    generateRemoteAppRdp,
    generateDesktopRdp,
};
