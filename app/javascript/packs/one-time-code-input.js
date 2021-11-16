import OneTimeCodeInput from '@18f/identity-one-time-code-input';

const fakeField = /** @type {HTMLInputElement?} */ (document.querySelector('.one-time-code-input'));

if (fakeField) {
  new OneTimeCodeInput(fakeField).bind();
}
