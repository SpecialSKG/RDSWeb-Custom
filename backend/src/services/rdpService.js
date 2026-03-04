const config = require('../config');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

function normalizeCollectionName(collectionName = '') {
    return String(collectionName || '')
        .trim()
    .replaceAll(/\s+/g, '_')
    .replaceAll(/\W/g, '_')
        .toUpperCase();
}

function signRdpContentDetailed(rdpContent) {
    const result = {
        content: rdpContent,
        signed: false,
        reason: 'SIGN_DISABLED',
    };

    if (!config.rdp.signing.enabled) {
        return result;
    }

    if (!config.rdp.signing.thumbprint) {
        const reason = 'MISSING_THUMBPRINT';
        console.warn('[rdpService] RDP_SIGN_ENABLED=true pero falta RDP_SIGN_CERT_THUMBPRINT. Se devuelve sin firma.');
        return { ...result, reason };
    }

    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rdweb-rdp-'));
    const rdpFilePath = path.join(tempDir, 'launch.rdp');

    try {
        fs.writeFileSync(rdpFilePath, rdpContent, { encoding: 'utf8' });

        const commandOutput = execFileSync(
            config.rdp.signing.toolPath,
            ['/sha1', config.rdp.signing.thumbprint, rdpFilePath],
            { windowsHide: true, timeout: 15000, encoding: 'utf8' }
        );

        const signedContent = fs.readFileSync(rdpFilePath, 'utf8');
        if (!signedContent.includes('signature:s:')) {
            console.warn('[rdpService] rdpsign se ejecutó pero el .rdp no contiene signature:s. Se devuelve sin firma.');
            return {
                ...result,
                reason: 'SIGNATURE_NOT_PRESENT',
                detail: String(commandOutput || '').trim(),
            };
        }

        return {
            content: signedContent,
            signed: true,
            reason: 'SIGNED_OK',
        };
    } catch (err) {
        const detail = [
            err?.message,
            err?.stdout?.toString?.(),
            err?.stderr?.toString?.(),
        ]
            .filter(Boolean)
            .join(' | ')
            .trim();

        const reason = err?.code === 'ENOENT' ? 'TOOL_NOT_FOUND' : 'SIGN_COMMAND_FAILED';
        console.error('[rdpService] No se pudo firmar el .rdp:', detail || err);
        return {
            ...result,
            reason,
            detail,
        };
    } finally {
        fs.rmSync(tempDir, { recursive: true, force: true });
    }
}

function signRdpContent(rdpContent) {
    return signRdpContentDetailed(rdpContent).content;
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
        `gatewayhostname:s:${config.rdGateway.hostname}`,
        `remoteapplicationname:s:${app.name}`,
        'remoteapplicationcmdline:s:',
        `workspace id:s:${fullAddress}`,
        'use redirection server name:i:1',
        `alternate full address:s:${fullAddress}`,
        `username:s:${username}`,
        `session timeout:i:${sessionTimeout * 60}`,
        'autoreconnection enabled:i:1',
    ];

    if (collectionName) {
        lines.push(`loadbalanceinfo:s:tsv://MS Terminal Services Plugin.1.${collectionName}`);
    }

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
    signRdpContent,
    signRdpContentDetailed,
};
