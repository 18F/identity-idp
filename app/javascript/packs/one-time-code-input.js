import OneTimeCodeInput from '@18f/identity-one-time-code-input';

const input = document.querySelector('.one-time-code-input');
const fakeField = document.querySelector('.hidden-input');
if (input && fakeField) {
  input.addEventListener('input', () => {
    fakeField.value = input.value;
  })
}
if (input) {
  new OneTimeCodeInput(/** @type {HTMLInputElement} */ (input)).bind();
}
