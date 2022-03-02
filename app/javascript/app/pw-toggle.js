import { t } from '@18f/identity-i18n';

function togglePw() {
  const inputs = document.querySelectorAll('input.password-toggle[type="password"]');

  if (inputs) {
    [].slice.call(inputs).forEach((input, i) => {
      input.parentNode.classList.add('position-relative');

      const el = `
        <div class="password-toggle__toggle">
          <input
            id="pw-toggle-${i}"
            type="checkbox"
            class="usa-checkbox__input usa-checkbox__input--bordered"
          >
          <label for="pw-toggle-${i}" class="usa-checkbox__label">
            ${t('forms.passwords.show')}
          </label>
        </div>`;
      input.insertAdjacentHTML('afterend', el);

      const toggle = document.getElementById(`pw-toggle-${i}`);
      toggle.addEventListener('change', function () {
        input.type = toggle.checked ? 'text' : 'password';
      });
    });
  }
}

document.addEventListener('DOMContentLoaded', togglePw);
