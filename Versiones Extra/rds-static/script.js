document.addEventListener('DOMContentLoaded', () => {
  const loginForm = document.getElementById('login-form');
  const loginView = document.getElementById('login-view');
  const dashboardView = document.getElementById('dashboard-view');
  const displayName = document.getElementById('display-name');
  const logoutBtn = document.getElementById('btn-logout');
  const loginBtn = document.getElementById('btn-login');
  const btnText = loginBtn ? loginBtn.querySelector('.btn-text') : null;
  const spinner = loginBtn ? loginBtn.querySelector('.loader-spinner') : null;

  if (loginForm && loginView && dashboardView) {
    loginForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const usernameInput = document.getElementById('username');
      const rawUser = usernameInput ? usernameInput.value.trim() : '';
      const userLabel = rawUser || 'Usuario';

      if (btnText) btnText.style.visibility = 'hidden';
      if (spinner) spinner.style.display = 'block';

      setTimeout(() => {
        if (displayName) displayName.textContent = userLabel;
        loginView.classList.remove('active');
        dashboardView.classList.add('active');
        if (btnText) btnText.style.visibility = 'visible';
        if (spinner) spinner.style.display = 'none';
      }, 600);
    });
  }

  if (logoutBtn && loginView && dashboardView) {
    logoutBtn.addEventListener('click', () => {
      dashboardView.classList.remove('active');
      loginView.classList.add('active');
      if (loginForm) loginForm.reset();
    });
  }

  document.querySelectorAll('[data-app]').forEach((card) => {
    card.addEventListener('click', (e) => {
      e.preventDefault();
      const appName = card.querySelector('.app-name')?.textContent || 'Aplicación';
      alert(`Versión estática: aquí normalmente se descargaría o lanzaría ${appName}.`);
    });
  });

  const connectBtn = document.getElementById('btn-connect-desktop');
  if (connectBtn) {
    connectBtn.addEventListener('click', (e) => {
      e.preventDefault();
      const machine = document.getElementById('machineName');
      const target = machine && machine.value.trim() ? machine.value.trim() : '[equipo-remoto]';
      alert(`Versión estática: aquí normalmente se generaría o descargaría el acceso RDP para ${target}.`);
    });
  }
});
