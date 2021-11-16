import OneTimeCodeInput from '@18f/identity-one-time-code-input';
import { loadPolyfills } from '@18f/identity-polyfill';

const fakeField = /** @type {HTMLInputElement?} */ (document.querySelector('.one-time-code-input'));

if (fakeField) {
  loadPolyfills(['custom-event']).then(() => new OneTimeCodeInput(fakeField).bind());
}
