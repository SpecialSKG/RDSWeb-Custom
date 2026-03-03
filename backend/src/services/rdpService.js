const config = require('../config');

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

    return [
        'screen mode id:i:1',
        'use multimon:i:0',
        'desktopwidth:i:1024',
        'desktopheight:i:768',
        'session bpp:i:32',
        'winposstr:s:0,1,0,0,800,600',
        'compression:i:1',
        'keyboardhook:i:2',
        'audiocapturemode:i:0',
        'videoplaybackmode:i:1',
        'connection type:i:7',
        'networkautodetect:i:1',
        'bandwidthautodetect:i:1',
        'displayconnectionbar:i:1',
        'enableworkspacereconnect:i:0',
        'disable wallpaper:i:0',
        'allow font smoothing:i:0',
        'allow desktop composition:i:0',
        'disable full window drag:i:1',
        'disable menu anims:i:1',
        'disable themes:i:0',
        'disable cursor setting:i:0',
        'bitmapcachepersistenable:i:1',
        // Dirección del servidor (Connection Broker)
        `full address:s:${app.remoteServer || config.rdcb.server}`,
        // RD Gateway
        `gatewayhostname:s:${config.rdGateway.hostname}`,
        'gatewayusagemethod:i:1',
        'gatewaycredentialssource:i:4',
        'gatewayprofileusagemethod:i:1',
        // Autenticación
        'promptcredentialonce:i:0',
        `username:s:${username}`,
        'authentication level:i:3',
        // RemoteApp
        'remoteapplicationmode:i:1',
        `remoteapplicationname:s:${app.name}`,
        `remoteapplicationprogram:s:${app.rdpPath}`,
        'remoteapplicationcmdline:s:',
        // Redirecciones
        'redirectprinters:i:1',
        'redirectclipboard:i:1',
        'redirectsmartcards:i:0',
        'redirectdrives:i:0',
        'redirectposdevices:i:0',
        // Sesión
        `session timeout:i:${sessionTimeout * 60}`,
        'autoreconnection enabled:i:1',
    ].join('\r\n');
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

module.exports = { generateRemoteAppRdp, generateDesktopRdp };
