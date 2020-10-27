import Cleave from 'cleave.js';

const { I18n } = window.LoginGov;

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

      let ssnCleave = new Cleave(input, {
        numericOnly: true,
        blocks: [3, 2, 4],
        delimiter: '',
      });

      const toggle = document.getElementById(`ssn-toggle-${i}`);
      toggle.addEventListener('change', function () {
        input.type = toggle.checked ? 'text' : 'password';

        if (!toggle.checked) {
          if (ssnCleave) {
            ssnCleave.destroy();

            ssnCleave = new Cleave(input, {
              numericOnly: true,
              blocks: [3, 2, 4],
              delimiter: '',
            });
          }

          input.value = input.value.replace(/-/g, '');
        } else {
          ssnCleave.destroy();
          ssnCleave = new Cleave(input, {
            numericOnly: true,
            blocks: [3, 2, 4],
            delimiter: '-',
          });
        }
      });
    });
  }
}

document.addEventListener('DOMContentLoaded', formatSSNField);
