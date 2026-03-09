window.addEventListener("load", function () {
  const preloader = document.getElementById("preloader");

  setTimeout(() => {
    if (preloader) {
      preloader.classList.add("hidden");
    }
  }, 500);
});

const togglePasswordBtn = document.getElementById("togglePassword");
const passwordInput = document.getElementById("password");
const form = document.getElementById("loginForm");
const formMessage = document.getElementById("formMessage");

if (togglePasswordBtn && passwordInput) {
  togglePasswordBtn.addEventListener("click", function () {
    const isPassword = passwordInput.type === "password";

    passwordInput.type = isPassword ? "text" : "password";
    togglePasswordBtn.setAttribute("aria-pressed", String(isPassword));
    togglePasswordBtn.setAttribute(
      "aria-label",
      isPassword ? "Ocultar contraseña" : "Mostrar contraseña"
    );
    togglePasswordBtn.classList.toggle("is-visible", isPassword);
  });
}

if (form) {
  form.addEventListener("submit", function (event) {
    event.preventDefault();

    const redirectUrl = form.dataset.redirect || "apps/apps.html";
    const submitButton = form.querySelector(".btn-submit");

    if (formMessage) {
      formMessage.textContent = "Ingresando al portal...";
    }

    if (submitButton) {
      submitButton.disabled = true;
    }

    setTimeout(() => {
      window.location.href = redirectUrl;
    }, 420);
  });
}
