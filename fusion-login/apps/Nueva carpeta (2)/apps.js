const appCards = document.querySelectorAll('.app-card');
const appCategories = document.querySelectorAll('.app-category');
const appsLaunchNote = document.getElementById('appsLaunchNote');
const appSearch = document.getElementById('appSearch');

appCards.forEach((card) => {
  card.addEventListener('click', function () {
    const appName = card.dataset.app || 'la aplicación seleccionada';

    if (appsLaunchNote) {
      appsLaunchNote.textContent = `Simulación activa: aquí se iniciaría ${appName} en una sesión remota.`;
      appsLaunchNote.classList.add('is-active');
      appsLaunchNote.classList.remove('is-empty');
    }
  });
});

function normalizeText(value) {
  return (value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

function filterApps() {
  const query = normalizeText(appSearch ? appSearch.value : '');
  let visibleApps = 0;

  appCategories.forEach((category) => {
    const categoryName = normalizeText(category.dataset.category || '');
    const cards = category.querySelectorAll('.app-card');
    let categoryVisible = 0;

    cards.forEach((card) => {
      const appName = normalizeText(card.dataset.app || '');
      const appCategory = normalizeText(card.dataset.category || '');
      const matches = !query || appName.includes(query) || appCategory.includes(query) || categoryName.includes(query);

      card.classList.toggle('is-hidden', !matches);

      if (matches) {
        categoryVisible += 1;
        visibleApps += 1;
      }
    });

    category.classList.toggle('is-hidden', categoryVisible === 0);
  });

  if (appsLaunchNote) {
    if (query && visibleApps === 0) {
      appsLaunchNote.textContent = 'No se encontraron aplicaciones que coincidan con la búsqueda.';
      appsLaunchNote.classList.remove('is-active');
      appsLaunchNote.classList.add('is-empty');
    } else if (query) {
      appsLaunchNote.textContent = `${visibleApps} aplicación${visibleApps === 1 ? '' : 'es'} visible${visibleApps === 1 ? '' : 's'} según la búsqueda.`;
      appsLaunchNote.classList.remove('is-active');
      appsLaunchNote.classList.add('is-empty');
    } else {
      appsLaunchNote.textContent = 'Esta vista es demostrativa. Al elegir una aplicación se mostrará una simulación de inicio.';
      appsLaunchNote.classList.remove('is-active');
      appsLaunchNote.classList.add('is-empty');
    }
  }
}

if (appSearch) {
  appSearch.addEventListener('input', filterApps);
}

filterApps();
