const appCards = document.querySelectorAll('.app-card');
const appsLaunchNote = document.getElementById('appsLaunchNote');

appCards.forEach((card) => {
  card.addEventListener('click', function () {
    const appName = card.dataset.app || 'la aplicación seleccionada';

    if (appsLaunchNote) {
      appsLaunchNote.textContent = `Simulación activa: aquí se iniciaría ${appName} en una sesión remota.`;
      appsLaunchNote.classList.add('is-active');
    }
  });
});
