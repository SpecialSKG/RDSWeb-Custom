const appCards = document.querySelectorAll('.app-card');
const appsLaunchNote = document.getElementById('appsLaunchNote');
const appsSearch = document.getElementById('appsSearch');
const appCategories = document.querySelectorAll('.apps-category');

appCards.forEach((card) => {
  card.addEventListener('click', function () {
    const appName = card.dataset.app || 'la aplicación seleccionada';

    if (appsLaunchNote) {
      appsLaunchNote.textContent = `Simulación activa: aquí se iniciaría ${appName} en una sesión remota.`;
      appsLaunchNote.classList.add('is-active');
    }
  });
});

if (appsSearch) {
  appsSearch.addEventListener('input', function () {
    const query = appsSearch.value.trim().toLowerCase();

    appCategories.forEach((category) => {
      const cards = category.querySelectorAll('.app-card');
      let visibleCount = 0;

      cards.forEach((card) => {
        const haystack = (card.dataset.search || card.dataset.app || '').toLowerCase();
        const matches = haystack.includes(query);
        card.hidden = !matches;

        if (matches) {
          visibleCount += 1;
        }
      });

      category.classList.toggle('is-empty', visibleCount === 0);
    });
  });
}
