import OneTimeCodeInput from '@18f/identity-one-time-code-input';

const fakeField = document.querySelector(".one-time-code-input");
const input = document.querySelector(".hidden-input");
if (input && fakeField) {
  fakeField.addEventListener('input', () => {
    input.value = fakeField.value;
  });
}
if (input) {
  new OneTimeCodeInput(/** @type {HTMLInputElement} */ (input)).bind();
}
