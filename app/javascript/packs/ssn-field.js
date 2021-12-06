import Cleave from 'cleave.js';

const { I18n } = window.LoginGov;

/* eslint-disable no-new */
function formatSSNFieldAndLimitLength() {
  const inputs = document.querySelectorAll('input.ssn-toggle[type="password"]');

  if (inputs) {
    [].slice.call(inputs).forEach((input, i) => {
      const el = `
        <div class="margin-top-1 display-flex flex-justify-end">
          <input
            id="ssn-toggle-${i}"
            type="checkbox"
            class="usa-checkbox__input usa-checkbox__input--bordered"
          >
          <label for="ssn-toggle-${i}" class="usa-checkbox__label">
            ${I18n.t('forms.ssn.show')}
          </label>
        </div>`;
      input.insertAdjacentHTML('afterend', el);

      const toggle = document.getElementById(`ssn-toggle-${i}`);

      let cleave;

      function sync() {
        const { value } = input;
        input.type = toggle.checked ? 'text' : 'password';
        cleave?.destroy();
        if (toggle.checked) {
          cleave = new Cleave(input, {
            numericOnly: true,
            blocks: [3, 2, 4],
            delimiter: '-',
          });
        } else {
          const nextValue = value.replace(/-/g, '');
          if (nextValue !== value) {
            input.value = nextValue;
          }
        }
        const didFormat = input.value !== value;
        if (didFormat) {
          input.checkValidity();
        }
      }

      sync();
      toggle.addEventListener('change', sync);

      function limitLength() {
        const maxLength = 9 + (this.value.match(/-/g) || []).length;
        if (this.value.length > maxLength) {
          this.value = this.value.slice(0, maxLength);
          this.checkValidity();
        }
      }

      input.addEventListener('input', limitLength.bind(input));
    });
  }
}

document.addEventListener('DOMContentLoaded', formatSSNFieldAndLimitLength);
