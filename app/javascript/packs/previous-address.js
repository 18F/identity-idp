import 'classlist.js';
import { TextField } from 'field-kit';
import ZipCodeFormatter from '../app/modules/zip-code-formatter';

const I18n = window.LoginGov.I18n;

function previousAddress() {
  const accordion = window.LoginGov.accordions.filter(a =>
    a.el === document.querySelector('.accordion'),
  )[0];

  if (!accordion) return;

  const header = accordion.el.querySelector('.accordion-header');
  const controls = accordion.el.querySelector('[aria-controls]');
  const selects = accordion.el.querySelectorAll('select');
  const inputs = accordion.el.querySelectorAll('input');
  const originalHeading = controls.textContent;

  header.classList.remove('display-none');

  let firstExpansion = true;

  accordion.on('accordion.hide', () => {
    controls.innerHTML = originalHeading;

    [].slice.call(inputs).forEach((input) => {
      input.value = ''; // eslint-disable-line no-param-reassign
    });

    [].slice.call(selects).forEach((select) => {
      select.selectedIndex = '0'; // eslint-disable-line no-param-reassign
    });
  });

  accordion.on('accordion.show', () => {
    controls.innerHTML = I18n.t('links.remove');

    if (firstExpansion) {
      /* eslint-disable no-new, no-shadow */
      new TextField(accordion.el.querySelector('.zipcode'), new ZipCodeFormatter());
      firstExpansion = false;
    }
  });
}

document.addEventListener('DOMContentLoaded', previousAddress);
