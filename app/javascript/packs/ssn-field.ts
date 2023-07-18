import Cleave from 'cleave.js';

function formatSSNFieldAndLimitLength() {
  const inputs = document.querySelectorAll<HTMLInputElement>('input.ssn-toggle[type="password"]');

  if (inputs) {
    inputs.forEach((input) => {
      const toggle = document.querySelector<HTMLInputElement>(`[aria-controls="${input.id}"]`)!;

      let cleave: Cleave | undefined;

      function sync() {
        const { value } = input;
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

      function limitLength(this: HTMLInputElement) {
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
