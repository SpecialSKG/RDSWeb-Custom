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
  {
    alias: "MSWORD",
    name: "Microsoft Word 2019",
    rdpPath: "||MSWORD",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Microsoft Office",
  },
  {
    alias: "MSEXCEL",
    name: "Microsoft Excel 2019",
    rdpPath: "||MSEXCEL",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Microsoft Office",
  },
  {
    alias: "MSPOWERPOINT",
    name: "Microsoft PowerPoint 2019",
    rdpPath: "||MSPOWERPOINT",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Microsoft Office",
  },
  {
    alias: "NOTEPADPP",
    name: "Notepad++",
    rdpPath: "||NOTEPADPP",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Herramientas",
  },
  {
    alias: "CHROME",
    name: "Google Chrome",
    rdpPath: "||CHROME",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Navegadores",
  },
  {
    alias: "ERP",
    name: "Sistema ERP",
    rdpPath: "||ERP",
    iconIndex: 0,
    remoteServer: config.rdcb.server,
    folderName: "Aplicaciones Empresariales",
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
    const userPermissionSet = getUserPermissionSet(user);
    const apps = SIMULATED_APPS.filter((app) =>
      isResourceAllowedForUser(app.allowedGroups, userPermissionSet),
    );
    const desktops = SIMULATED_DESKTOPS.filter((desktop) =>
      isResourceAllowedForUser(desktop.allowedGroups, userPermissionSet),
    );

    return {
      apps,
      desktops,
    };
  }

  // ── MODO REAL — PowerShell (RemoteDesktop Module) ─────────────────────────
  try {
    // Silenciamos advertencias y manejamos errores silenciosamente para no romper el JSON
    const psScript = `$WarningPreference = 'SilentlyContinue'; $ErrorActionPreference = 'SilentlyContinue'; $apps = Get-RDRemoteApp -ConnectionBroker '${config.rdcb.server}' | Where-Object { $_.ShowInWebAccess -eq $true } | Select-Object -Property DisplayName, Alias, FolderName, CollectionName, UserGroups; if ($apps) { $apps | ConvertTo-Json -Compress -Depth 5 } else { '[]' }`;

    const result = execSync(
      `powershell.exe -NonInteractive -NoProfile -Command "${psScript}"`,
      { encoding: "utf8", timeout: 15000, windowsHide: true },
    );

    // Limpiamos cualquier posible texto residual antes del JSON (por si PowerShell es terco)
    const jsonString =
      result.substring(result.indexOf("["), result.lastIndexOf("]") + 1) ||
      "[]";

    const raw = JSON.parse(jsonString);
    const appsArray = Array.isArray(raw) ? raw : [raw];

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

    const userPermissionSet = getUserPermissionSet(user);
    const filteredApps = apps.filter((app) =>
      isResourceAllowedForUser(app.allowedGroups, userPermissionSet),
    );

    return { apps: filteredApps, desktops: [] };
  } catch (err) {
    console.error("[rdcbService] Error ejecutando PowerShell:", err.message);
    throw new Error("No se pudo contactar al RD Connection Broker");
  }
}

module.exports = { getAppsForUser };
