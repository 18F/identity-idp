import 'classlist.js';
import { TextField } from 'field-kit';
import ZipCodeFormatter from '../app/modules/zip-code-formatter';

const I18n = window.LoginGov.I18n;

function previousAddress() {
  const accordion = document.querySelector('.accordion');

  if (accordion) {
    const header = accordion.querySelector('.accordion-header');
    const controls = accordion.querySelector('[aria-controls]');
    const selects = accordion.querySelectorAll('select');
    const inputs = accordion.querySelectorAll('input');
    const originalHeading = controls.textContent;

    header.classList.remove('display-none');

    let firstExpansion = true;
    controls.addEventListener('click', function() {
      const expandedState = controls.getAttribute('aria-expanded');

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

        if (firstExpansion) {
          /* eslint-disable no-new, no-shadow */
          new TextField(accordion.querySelector('.zipcode'), new ZipCodeFormatter());
          firstExpansion = false;
        }
      }
    });
  }
}

document.addEventListener('DOMContentLoaded', previousAddress);
