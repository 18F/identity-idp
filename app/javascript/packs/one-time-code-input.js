import OneTimeCodeInput from '@18f/identity-one-time-code-input';

function checkInputValidity(event) {
  const input = /** @type {HTMLInputElement} */ (event.target);
  input.setAttribute('aria-invalid', 'false');
  input.classList.remove('usa-input--error');
  if (
    event.type === 'invalid' &&
    !input.validity.valid &&
    input.parentNode?.querySelector('.display-if-invalid')
  ) {
    event.preventDefault();
    input.setAttribute('aria-invalid', 'true');
    input.classList.add('usa-input--error');
  }
}

const input = document.querySelector('.one-time-code-input');
if (input) {
  new OneTimeCodeInput(/** @type {HTMLInputElement} */ (input)).bind();
  input.addEventListener('input', checkInputValidity);
  input.addEventListener('invalid', checkInputValidity);
}
