const { execSync } = require("node:child_process");
const config = require("../config");

function normalizeGroupName(value = "") {
  let candidate = value;
  if (typeof value === "object" && value !== null) {
    const groupObject = value;
    candidate =
      groupObject?.name ||
      groupObject?.Name ||
      groupObject?.accountName ||
      groupObject?.AccountName ||
      groupObject?.distinguishedName ||
      groupObject?.DistinguishedName ||
      groupObject?.value ||
      groupObject?.Value ||
      "";
  }

  const raw = String(candidate || "").trim();
  if (!raw) return "";

  if (/^CN=/i.test(raw)) {
    return raw.split(",")[0].replace(/^CN=/i, "").trim().toLowerCase();
  }

  if (raw.includes("\\")) {
    const parts = raw.split("\\");
    return (parts.at(-1) || "").trim().toLowerCase();
  }

  return raw.toLowerCase();
}

function getUserPermissionSet(user) {
  const userGroups = Array.isArray(user?.groups) ? user.groups : [];
  const username = String(user?.username || "").trim();
  const domain = String(user?.domain || config.ldap.domain || "").trim();
  const email = String(user?.email || "").trim();

  const principals = [...userGroups];

  if (username) {
    principals.push(username);
    if (domain) {
      principals.push(`${domain}\\${username}`);
    }
  }

  if (email) {
    principals.push(email);
    const upnUser = email.split("@")[0];
    if (upnUser) {
      principals.push(upnUser);
    }
  }

  const normalized = principals
    .map((entry) => normalizeGroupName(entry))
    .filter(Boolean);

  return new Set(normalized);
}

function isResourceAllowedForUser(resourceGroups, userPermissionSet) {
  let groups = [];
  if (Array.isArray(resourceGroups)) {
    groups = resourceGroups;
  } else if (resourceGroups) {
    groups = [resourceGroups];
  }

  if (groups.length === 0) {
    return true;
  }

  const normalizedResourceGroups = groups
    .map((g) => normalizeGroupName(g))
    .filter(Boolean);

  if (normalizedResourceGroups.length === 0) {
    return true;
  }

  return normalizedResourceGroups.some((group) => userPermissionSet.has(group));
}

// ── Aplicaciones simuladas ─────────────────────────────────────────────────
const SIMULATED_APPS = [
  // ── Microsoft Office ─────────────────────────────────────────
  {
    alias: "MSWORD",
    name: "Microsoft Word 2019",
    rdpPath: "||MSWORD",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Microsoft Office",
    collectionName: "Office Apps",
  },
  {
    alias: "MSEXCEL",
    name: "Microsoft Excel 2019",
    rdpPath: "||MSEXCEL",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Microsoft Office",
    collectionName: "Office Apps",
  },
  {
    alias: "MSPOWERPOINT",
    name: "Microsoft PowerPoint 2019",
    rdpPath: "||MSPOWERPOINT",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Microsoft Office",
    collectionName: "Office Apps",
  },
  {
    alias: "MSOUTLOOK",
    name: "Microsoft Outlook 2019",
    rdpPath: "||MSOUTLOOK",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Microsoft Office",
    collectionName: "Office Apps",
  },
  {
    alias: "MSONENOTE",
    name: "Microsoft OneNote 2019",
    rdpPath: "||MSONENOTE",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Microsoft Office",
    collectionName: "Office Apps",
  },
  // ── Herramientas ─────────────────────────────────────────────
  {
    alias: "NOTEPADPP",
    name: "Notepad++",
    rdpPath: "||NOTEPADPP",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Herramientas",
    collectionName: "Utilidades",
  },
  {
    alias: "PUTTY",
    name: "PuTTY SSH Client",
    rdpPath: "||PUTTY",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Herramientas",
    collectionName: "Utilidades",
    allowedGroups: ["Desarrollo", "Domain Admins"],
  },
  {
    alias: "WINSCP",
    name: "WinSCP",
    rdpPath: "||WINSCP",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Herramientas",
    collectionName: "Utilidades",
    allowedGroups: ["Desarrollo", "Domain Admins"],
  },
  {
    alias: "CALC",
    name: "Calculadora",
    rdpPath: "||CALC",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Herramientas",
    collectionName: "Utilidades",
  },
  // ── Navegadores ──────────────────────────────────────────────
  {
    alias: "CHROME",
    name: "Google Chrome",
    rdpPath: "||CHROME",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Navegadores",
    collectionName: "Web Browsers",
  },
  {
    alias: "FIREFOX",
    name: "Mozilla Firefox",
    rdpPath: "||FIREFOX",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Navegadores",
    collectionName: "Web Browsers",
  },
  {
    alias: "MSEDGE",
    name: "Microsoft Edge",
    rdpPath: "||MSEDGE",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Navegadores",
    collectionName: "Web Browsers",
  },
  // ── Aplicaciones Empresariales ───────────────────────────────
  {
    alias: "ERP",
    name: "Sistema ERP",
    rdpPath: "||ERP",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Aplicaciones Empresariales",
    collectionName: "Business Apps",
    allowedGroups: ["Contabilidad", "Domain Admins"],
  },
  {
    alias: "CRM",
    name: "CRM Ventas",
    rdpPath: "||CRM",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Aplicaciones Empresariales",
    collectionName: "Business Apps",
    allowedGroups: ["Contabilidad", "Domain Admins"],
  },
  {
    alias: "NOMINAS",
    name: "Sistema de Nóminas",
    rdpPath: "||NOMINAS",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Aplicaciones Empresariales",
    collectionName: "Business Apps",
    allowedGroups: ["RRHH", "Domain Admins"],
  },
  {
    alias: "CONTPAQ",
    name: "CONTPAQi Contabilidad",
    rdpPath: "||CONTPAQ",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Aplicaciones Empresariales",
    collectionName: "Business Apps",
    allowedGroups: ["Contabilidad", "Domain Admins"],
  },
  // ── Desarrollo ───────────────────────────────────────────────
  {
    alias: "VSCODE",
    name: "Visual Studio Code",
    rdpPath: "||VSCODE",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Desarrollo",
    collectionName: "Dev Tools",
    allowedGroups: ["Desarrollo", "Domain Admins"],
  },
  {
    alias: "SSMS",
    name: "SQL Server Management Studio",
    rdpPath: "||SSMS",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Desarrollo",
    collectionName: "Dev Tools",
    allowedGroups: ["Desarrollo", "Domain Admins"],
  },
];

const SIMULATED_DESKTOPS = [
  {
    alias: "DESKTOP_DEFAULT",
    name: "Escritorio Remoto",
    rdpPath: null,
    remoteServer: config.rdcb.server,
    folderName: "Escritorios",
  },
  {
    alias: "DESKTOP_DEV",
    name: "Escritorio Desarrollo",
    rdpPath: null,
    remoteServer: config.rdcb.server,
    folderName: "Escritorios",
    allowedGroups: ["Desarrollo", "Domain Admins"],
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
  console.log(`[rdcbService] getAppsForUser → usuario: ${user?.username}, dominio: ${user?.domain}, grupos AD: [${(user?.groups || []).join(', ')}]`);

  const userPermissionSet = getUserPermissionSet(user);
  console.log(`[rdcbService] Permission set (${userPermissionSet.size} entradas): [${[...userPermissionSet].join(', ')}]`);

  if (config.simulation.enabled) {
    const apps = SIMULATED_APPS.filter((app) =>
      isResourceAllowedForUser(app.allowedGroups, userPermissionSet),
    );
    const desktops = SIMULATED_DESKTOPS.filter((desktop) =>
      isResourceAllowedForUser(desktop.allowedGroups, userPermissionSet),
    );
    console.log(`[rdcbService] SIMULACIÓN → apps permitidas: ${apps.length}, escritorios: ${desktops.length}`);
    return { apps, desktops };
  }

  // ── MODO REAL — PowerShell (RemoteDesktop Module) ─────────────────────────
  try {
    const psScript = `
      $WarningPreference = 'SilentlyContinue';
      $ErrorActionPreference = 'Stop';
      Import-Module RemoteDesktop -ErrorAction Stop;
      $all = Get-RDRemoteApp -ConnectionBroker '${config.rdcb.server}' -ErrorAction Stop;
      $visible = @($all | Where-Object { $_.ShowInWebAccess -eq $true });
      if ($visible.Count -gt 0) { $visible | Select-Object DisplayName, Alias, FolderName, CollectionName, UserGroups | ConvertTo-Json -Compress -Depth 5 } else { '[]' }
    `.replaceAll(/\n\s*/g, ' ').trim();

    console.log(`[rdcbService] Ejecutando PowerShell contra ${config.rdcb.server}...`);

    const result = execSync(
      `powershell.exe -NonInteractive -NoProfile -Command "${psScript}"`,
      { encoding: "utf8", timeout: 20000, windowsHide: true },
    );

    console.log(`[rdcbService] Salida raw PS (primeros 500 chars): ${String(result).substring(0, 500)}`);

    // Limpiamos cualquier posible texto residual antes del JSON (por si PowerShell es terco)
    const jsonString =
      result.substring(result.indexOf("["), result.lastIndexOf("]") + 1) ||
      "[]";

    const raw = JSON.parse(jsonString);
    const appsArray = Array.isArray(raw) ? raw : [raw];
    console.log(`[rdcbService] RDCB devolvió ${appsArray.length} apps totales`);

    const apps = appsArray.map((a) => {
      let allowedGroups = [];
      if (Array.isArray(a.UserGroups)) {
        allowedGroups = a.UserGroups;
      } else if (a.UserGroups) {
        allowedGroups = [a.UserGroups];
      }

      return {
        alias: a.Alias,
        name: a.DisplayName,
        rdpPath: `||${a.Alias}`,
        iconIndex: 0,
        remoteServer: config.rdcb.server,
        collectionName: a.CollectionName || '',
        folderName: a.FolderName || "Aplicaciones",
        allowedGroups,
      };
    });

    const filteredApps = apps.filter((app) => {
      const allowed = isResourceAllowedForUser(app.allowedGroups, userPermissionSet);
      console.log(`[rdcbService]   app "${app.alias}" allowedGroups=[${app.allowedGroups.map(g => normalizeGroupName(g)).join(', ')}] → ${allowed ? 'PERMITIDA' : 'DENEGADA'}`);
      return allowed;
    });

    console.log(`[rdcbService] Apps después de filtrar: ${filteredApps.length}/${apps.length}`);
    return { apps: filteredApps, desktops: [] };
  } catch (err) {
    console.error("[rdcbService] Error ejecutando PowerShell:", err.message);
    console.error("[rdcbService] stdout:", String(err.stdout || '').substring(0, 1000));
    console.error("[rdcbService] stderr:", String(err.stderr || '').substring(0, 1000));
    throw new Error("No se pudo contactar al RD Connection Broker");
  }
}

module.exports = { getAppsForUser };
