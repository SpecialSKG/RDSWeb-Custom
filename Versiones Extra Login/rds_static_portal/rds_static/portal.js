const STORAGE_KEYS = {
  sessionUser: 'rds_static_user',
  sessionPrivate: 'rds_static_private_machine',
  avatarPrefix: 'rds_static_avatar_',
  theme: 'rds_static_theme'
};

const APPS = [
  { name: 'Word 2019', publisher: 'Microsoft Office', category: 'Microsoft Corporation / Microsoft Office', theme: 'word', icon: 'W', url: '#word' },
  { name: 'Excel 2019', publisher: 'Microsoft Office', category: 'Microsoft Corporation / Microsoft Office', theme: 'excel', icon: 'X', url: '#excel' },
  { name: 'PowerPoint 2019', publisher: 'Microsoft Office', category: 'Microsoft Corporation / Microsoft Office', theme: 'powerpoint', icon: 'P', url: '#powerpoint' },
  { name: 'Outlook 2019', publisher: 'Microsoft Office', category: 'Microsoft Corporation / Microsoft Office', theme: 'outlook', icon: 'O', url: '#outlook' },
  { name: 'Chrome', publisher: 'Google', category: 'Navegadores', theme: 'browser', icon: 'C', url: '#chrome' },
  { name: 'Edge', publisher: 'Microsoft', category: 'Navegadores', theme: 'browser', icon: 'E', url: '#edge' },
  { name: 'ServiceDesk Plus', publisher: 'ManageEngine', category: 'Aplicaciones Empresariales', theme: 'business', icon: 'S', url: '#servicedesk' },
  { name: 'Zoho Creator', publisher: 'Zoho', category: 'Aplicaciones Empresariales', theme: 'business', icon: 'Z', url: '#zoho' },
  { name: 'Visual Studio Code', publisher: 'Microsoft', category: 'Desarrollo', theme: 'dev', icon: 'VS', url: '#vscode' },
  { name: 'SQL Server Management Studio', publisher: 'Microsoft', category: 'Desarrollo', theme: 'dev', icon: 'SQL', url: '#ssms' },
  { name: 'Herramienta de Reportes', publisher: 'Interno', category: 'Herramientas', theme: 'tool', icon: 'R', url: '#reportes' },
  { name: 'Escritorio Corporativo', publisher: 'Remote Desktop', category: 'Escritorios Remotos', theme: 'desktop', icon: 'RD', url: '#desktop' }
];

document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  bindThemeToggle();

  const page = document.body.dataset.page;

  if (page === 'login') {
    initLoginPage();
  }

  if (page === 'apps') {
    initAppsPage();
  }
});

function initTheme() {
  const saved = localStorage.getItem(STORAGE_KEYS.theme) || 'dark';
  document.body.classList.toggle('light-mode', saved === 'light');
  updateThemeIcon();
}

function bindThemeToggle() {
  const toggle = document.getElementById('theme-toggle');
  if (!toggle) return;

  toggle.addEventListener('click', () => {
    const isLight = document.body.classList.toggle('light-mode');
    localStorage.setItem(STORAGE_KEYS.theme, isLight ? 'light' : 'dark');
    updateThemeIcon();
  });
}

function updateThemeIcon() {
  const toggle = document.getElementById('theme-toggle');
  if (!toggle) return;
  toggle.textContent = document.body.classList.contains('light-mode') ? '☀️' : '🌙';
}

function initLoginPage() {
  const form = document.getElementById('login-form');
  const usernameInput = document.getElementById('username');
  const privateInput = document.getElementById('private-machine');
  const errorBox = document.getElementById('login-error');
  const submitBtn = document.getElementById('submit-login');

  const savedUser = sessionStorage.getItem(STORAGE_KEYS.sessionUser) || '';
  if (savedUser) {
    usernameInput.value = savedUser;
  }

  form.addEventListener('submit', (event) => {
    event.preventDefault();
    errorBox.hidden = true;
    errorBox.textContent = '';

    const username = usernameInput.value.trim();
    const password = document.getElementById('password').value.trim();

    if (!username.includes('\\')) {
      errorBox.textContent = 'Escribe el usuario en formato dominio\\usuario.';
      errorBox.hidden = false;
      return;
    }

    if (!password) {
      errorBox.textContent = 'Debes ingresar una contraseña.';
      errorBox.hidden = false;
      return;
    }

    submitBtn.classList.add('is-loading');
    submitBtn.disabled = true;

    sessionStorage.setItem(STORAGE_KEYS.sessionUser, username);
    sessionStorage.setItem(STORAGE_KEYS.sessionPrivate, privateInput.checked ? 'true' : 'false');

    window.setTimeout(() => {
      window.location.href = 'apps.html';
    }, 450);
  });
}

function initAppsPage() {
  const sessionUser = sessionStorage.getItem(STORAGE_KEYS.sessionUser);

  if (!sessionUser) {
    window.location.href = 'login.html';
    return;
  }

  const cleanUser = normalizeUser(sessionUser);
  document.getElementById('display-name').textContent = cleanUser;
  hydrateAvatar(cleanUser);
  hydrateCategoryFilter();
  renderApps();

  document.getElementById('search-apps').addEventListener('input', renderApps);
  document.getElementById('filter-category').addEventListener('change', renderApps);
  document.getElementById('logout-btn').addEventListener('click', logout);
  document.getElementById('avatar-input').addEventListener('change', handleAvatarChange);
}

function normalizeUser(rawUser) {
  const simple = rawUser.includes('\\') ? rawUser.split('\\')[1] : rawUser;
  if (!simple) return 'Usuario';
  return simple.charAt(0).toUpperCase() + simple.slice(1);
}

function hydrateCategoryFilter() {
  const select = document.getElementById('filter-category');
  const categories = [...new Set(APPS.map(app => app.category))].sort((a, b) => a.localeCompare(b, 'es'));

  categories.forEach(category => {
    const option = document.createElement('option');
    option.value = category;
    option.textContent = category;
    select.appendChild(option);
  });
}

function renderApps() {
  const searchValue = document.getElementById('search-apps').value.trim().toLowerCase();
  const categoryValue = document.getElementById('filter-category').value;
  const host = document.getElementById('apps-groups');
  const groupTemplate = document.getElementById('group-template');
  const cardTemplate = document.getElementById('app-card-template');

  host.innerHTML = '';

  const filtered = APPS.filter(app => {
    const matchesCategory = categoryValue === 'all' || app.category === categoryValue;
    const haystack = `${app.name} ${app.publisher} ${app.category}`.toLowerCase();
    const matchesSearch = !searchValue || haystack.includes(searchValue);
    return matchesCategory && matchesSearch;
  });

  if (!filtered.length) {
    host.innerHTML = '<section class="card empty-state">No se encontraron aplicaciones con ese filtro.</section>';
    return;
  }

  const grouped = filtered.reduce((acc, app) => {
    if (!acc[app.category]) acc[app.category] = [];
    acc[app.category].push(app);
    return acc;
  }, {});

  Object.keys(grouped).sort((a, b) => a.localeCompare(b, 'es')).forEach(category => {
    const apps = grouped[category];
    const groupNode = groupTemplate.content.firstElementChild.cloneNode(true);
    groupNode.querySelector('.group-title').textContent = category;
    groupNode.querySelector('.group-subtitle').textContent = 'Grupo generado desde la versión estática local.';
    groupNode.querySelector('.group-count').textContent = `${apps.length} app${apps.length === 1 ? '' : 's'}`;

    const grid = groupNode.querySelector('.apps-grid');

    apps.forEach(app => {
      const cardNode = cardTemplate.content.firstElementChild.cloneNode(true);
      cardNode.dataset.theme = app.theme;
      cardNode.querySelector('.app-icon').textContent = app.icon;
      cardNode.querySelector('.app-name').textContent = app.name;
      cardNode.querySelector('.app-publisher').textContent = app.publisher;

      const link = cardNode.querySelector('.app-link');
      link.href = app.url;
      link.addEventListener('click', (event) => {
        if (app.url.startsWith('#')) {
          event.preventDefault();
          alert(`Aquí debes reemplazar el enlace de ejemplo de "${app.name}" por la URL, .rdp o destino real.`);
        }
      });

      grid.appendChild(cardNode);
    });

    host.appendChild(groupNode);
  });
}

function hydrateAvatar(user) {
  const avatarImage = document.getElementById('avatar-image');
  const avatarFallback = document.getElementById('avatar-fallback');
  const key = STORAGE_KEYS.avatarPrefix + user.toLowerCase();
  const saved = localStorage.getItem(key);

  avatarFallback.textContent = user.charAt(0).toUpperCase();

  if (saved) {
    avatarImage.src = saved;
    avatarImage.hidden = false;
    avatarFallback.hidden = true;
  }
}

function handleAvatarChange(event) {
  const file = event.target.files?.[0];
  if (!file) return;

  const user = document.getElementById('display-name').textContent.trim() || 'usuario';
  const reader = new FileReader();

  reader.onload = () => {
    const key = STORAGE_KEYS.avatarPrefix + user.toLowerCase();
    try {
      localStorage.setItem(key, reader.result);
      hydrateAvatar(user);
    } catch (error) {
      alert('No se pudo guardar el avatar. Prueba con una imagen más liviana.');
    }
  };

  reader.readAsDataURL(file);
}

function logout() {
  sessionStorage.removeItem(STORAGE_KEYS.sessionUser);
  sessionStorage.removeItem(STORAGE_KEYS.sessionPrivate);
  window.location.href = 'login.html';
}
