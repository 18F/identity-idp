import OneTimeCodeInput from '@18f/identity-one-time-code-input';

const fakeField = /** @type {HTMLInputElement?} */ (document.querySelector('.one-time-code-input'));

if (fakeField) {
  const el = `<input type="hidden" name="code" id="code" class="hidden-input">`;
  fakeField.insertAdjacentHTML('afterend', el);
  fakeField.removeAttribute('name');
  fakeField.removeAttribute('id');
  const hiddenInput = /** @type {HTMLInputElement?} */ (document.getElementById(`code`));
  if (hiddenInput && fakeField) {
    fakeField.addEventListener('input', () => {
      hiddenInput.value = fakeField.value;
    });
  }
}
if (fakeField) {
  new OneTimeCodeInput(fakeField).bind();
}
