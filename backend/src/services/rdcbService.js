const { execSync } = require('child_process');
const config = require('../config');

// ── Aplicaciones simuladas ─────────────────────────────────────────────────
const SIMULATED_APPS = [
    {
        alias: 'MSWORD',
        name: 'Microsoft Word 2019',
        rdpPath: '||MSWORD',
        iconIndex: 0,
        remoteServer: config.rdcb.server,
        folderName: 'Microsoft Office',
    },
    {
        alias: 'MSEXCEL',
        name: 'Microsoft Excel 2019',
        rdpPath: '||MSEXCEL',
        iconIndex: 0,
        remoteServer: config.rdcb.server,
        folderName: 'Microsoft Office',
    },
    {
        alias: 'MSPOWERPOINT',
        name: 'Microsoft PowerPoint 2019',
        rdpPath: '||MSPOWERPOINT',
        iconIndex: 0,
        remoteServer: config.rdcb.server,
        folderName: 'Microsoft Office',
    },
    {
        alias: 'NOTEPADPP',
        name: 'Notepad++',
        rdpPath: '||NOTEPADPP',
        iconIndex: 0,
        remoteServer: config.rdcb.server,
        folderName: 'Herramientas',
    },
    {
        alias: 'CHROME',
        name: 'Google Chrome',
        rdpPath: '||CHROME',
        iconIndex: 0,
        remoteServer: config.rdcb.server,
        folderName: 'Navegadores',
    },
    {
        alias: 'ERP',
        name: 'Sistema ERP',
        rdpPath: '||ERP',
        iconIndex: 0,
        remoteServer: config.rdcb.server,
        folderName: 'Aplicaciones Empresariales',
    },
];

const SIMULATED_DESKTOPS = [
    {
        alias: 'DESKTOP_DEFAULT',
        name: 'Escritorio Remoto',
        rdpPath: null,
        remoteServer: config.rdcb.server,
        folderName: 'Escritorios',
    },
];

/**
 * Obtiene las RemoteApps y escritorios disponibles para el usuario.
 * En modo simulación devuelve datos estáticos.
 * En modo real ejecuta PowerShell contra el RD Connection Broker.
 *
 * @param {object} user  — objeto de usuario con username, domain, sid
 * @returns {Promise<{apps: Array, desktops: Array}>}
 */
async function getAppsForUser(user) {
    if (config.simulation.enabled) {
        return {
            apps: SIMULATED_APPS,
            desktops: SIMULATED_DESKTOPS,
        };
    }

    // ── MODO REAL — PowerShell / WMI ──────────────────────────────────────────
    try {
        const psScript = `
      $apps = Get-WmiObject -Namespace "root\\cimv2\\TerminalServices" \\
        -Class Win32_TSPublishedApplication \\
        -ComputerName "${config.rdcb.server}" | 
        Select-Object -Property Name, Alias, VPath, IconPath, FolderName
      $apps | ConvertTo-Json -Compress
    `;
        const result = execSync(
            `powershell -NonInteractive -Command "${psScript.replace(/\n/g, ' ')}"`,
            { encoding: 'utf8', timeout: 10000 }
        );
        const raw = JSON.parse(result || '[]');
        const appsArray = Array.isArray(raw) ? raw : [raw];

        const apps = appsArray.map((a) => ({
            alias: a.Alias,
            name: a.Name,
            rdpPath: `||${a.Alias}`,
            iconIndex: 0,
            remoteServer: config.rdcb.server,
            folderName: a.FolderName || 'Aplicaciones',
        }));

        return { apps, desktops: [] };
    } catch (err) {
        console.error('[rdcbService] Error consultando WMI:', err.message);
        throw new Error('No se pudo contactar al RD Connection Broker');
    }
}

module.exports = { getAppsForUser };
