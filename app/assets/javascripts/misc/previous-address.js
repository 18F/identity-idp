import 'classlist.js';

const I18n = window.LoginGov.I18n;

function previousAddress() {
  const accordion = document.querySelector('.accordion');

  if (accordion) {
    const controls = accordion.querySelector('[aria-controls]');
    const selects = accordion.querySelectorAll('select');
    const inputs = accordion.querySelectorAll('input');

    controls.classList.remove('display-none');

    const originalHeading = controls.textContent;

    controls.addEventListener('click', function() {
      const expandedState = accordion.getAttribute('aria-expanded');

      if (expandedState === 'false') {
        controls.innerHTML = originalHeading;

        [].slice.call(inputs).forEach((input) => {
          input.value = ''; // eslint-disable-line no-param-reassign
        });

        [].slice.call(selects).forEach((select) => {
          select.selectedIndex = '0'; // eslint-disable-line no-param-reassign
        });
      } else if (expandedState === 'true') {
        controls.innerHTML = I18n.t('links.remove');
      }
    });
  }
}

document.addEventListener('DOMContentLoaded', previousAddress);
