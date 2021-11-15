import OneTimeCodeInput from '@18f/identity-one-time-code-input';

const fakeField = /** @type {HTMLInputElement?} */ (document.querySelector('.one-time-code-input'));

if (fakeField) {
  const hiddenInput = /** @type {HTMLInputElement} */ (document.createElement('input'));
  hiddenInput.name = fakeField.name;
  hiddenInput.value = fakeField.value;
  hiddenInput.type = 'hidden';
  /** @type {HTMLElement} */ (fakeField.parentNode).insertBefore(hiddenInput, fakeField);
  fakeField.removeAttribute('name');
  if (hiddenInput && fakeField) {
    fakeField.addEventListener('input', () => {
      hiddenInput.value = fakeField.value;
    });
  }
  new OneTimeCodeInput(fakeField).bind();
}
