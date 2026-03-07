window.addEventListener("load", function () {
  const preloader = document.getElementById("preloader");

  setTimeout(() => {
    preloader.classList.add("hidden");
  }, 500); // duración visible del preload
});

const togglePasswordBtn = document.getElementById('togglePassword');
const passwordInput = document.getElementById('password');
const form = document.getElementById('loginForm');
const formMessage = document.getElementById('formMessage');

if (togglePasswordBtn && passwordInput) {
  togglePasswordBtn.addEventListener('click', function () {
    const isPassword = passwordInput.type === 'password';

    passwordInput.type = isPassword ? 'text' : 'password';
    togglePasswordBtn.setAttribute('aria-pressed', String(isPassword));
    togglePasswordBtn.setAttribute(
      'aria-label',
      isPassword ? 'Ocultar contraseña' : 'Mostrar contraseña'
    );
  });
}

if (form) {
  form.addEventListener('submit', function (event) {
    event.preventDefault();

    const username = document.getElementById('username').value.trim();
    const password = passwordInput.value.trim();

    if (!username || !password) {
      formMessage.textContent = 'Completa el usuario y la contraseña.';
      return;
    }

    formMessage.textContent = 'Formulario listo para conectar con tu backend.';
  });
}
