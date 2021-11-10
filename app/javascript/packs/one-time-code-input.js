import OneTimeCodeInput from '@18f/identity-one-time-code-input';

const fakeField = /** @type {HTMLInputElement?} */ (document.querySelector('.one-time-code-input'));
const input = /** @type {HTMLInputElement?} */ (document.querySelector('.hidden-input'));
if (input && fakeField) {
  fakeField.addEventListener('input', () => {
    input.value = fakeField.value;
  });
}
if (fakeField) {
  new OneTimeCodeInput(fakeField).bind();
}
