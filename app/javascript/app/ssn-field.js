import Cleave from 'cleave.js';

const { I18n } = window.LoginGov;

function sync(input, toggle, ssnCleave) {
  input.type = toggle.checked ? 'text' : 'password';

  ssnCleave?.destroy();

  if (toggle.checked) {
    return new Cleave(input, {
      numericOnly: true,
      blocks: [3, 2, 4],
      delimiter: '-',
    });
  }

  const nextValue = input.value.replace(/-/g, '');
  if (input.value !== nextValue) {
    input.value = nextValue;
  }

  return null;
}

/* eslint-disable no-new */
function formatSSNField() {
  const inputs = document.querySelectorAll('input.ssn-toggle[type="password"]');

  if (inputs) {
    [].slice.call(inputs).forEach((input, i) => {
      const el = `
        <div class="mt1 right">
          <label class="btn-border" for="ssn-toggle-${i}">
            <div class="checkbox">
              <input id="ssn-toggle-${i}" type="checkbox">
              <span class="indicator"></span>
              ${I18n.t('forms.ssn.show')}
            </div>
          </label>
        </div>`;
      input.insertAdjacentHTML('afterend', el);

      const toggle = document.getElementById(`ssn-toggle-${i}`);
      let ssnCleave;

      ssnCleave = sync(input, toggle, ssnCleave);

      toggle.addEventListener('change', function () {
        ssnCleave = sync(input, toggle, ssnCleave);
      });
    });
  }
}

document.addEventListener('DOMContentLoaded', formatSSNField);
