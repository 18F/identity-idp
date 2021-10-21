import OneTimeCodeInput from '@18f/identity-one-time-code-input';

const input = document.querySelector('.one-time-code-input');
if (input) {
  new OneTimeCodeInput(/** @type {HTMLInputElement} */ (input)).bind();
}
