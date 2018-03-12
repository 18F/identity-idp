import { isValidNumber } from 'libphonenumber-js';

const checkPhoneValidity = () => {
  const sendCodeButton = document.querySelector('[data-international-phone-form] input[name=commit]');
  const phoneInput = document.querySelector('[data-international-phone-form] .phone');
  const countryCodeInput = document.querySelector('[data-international-phone-form] .international-code');

  if (phoneInput && countryCodeInput && sendCodeButton) {
    const phone = phoneInput.value;
    const countryCode = countryCodeInput.value;

    const phoneValid = isValidNumber(phone, countryCode);

    if (phoneValid) {
      sendCodeButton.disabled = false;
    } else {
      phoneInput.dispatchEvent(new Event('invalid'));
      sendCodeButton.disabled = true;
    }
  }
};

document.addEventListener('DOMContentLoaded', () => {
  const intlPhoneInput = document.querySelector('[data-international-phone-form] .phone');
  const codeInput = document.querySelector('[data-international-phone-form] .international-code');
  if (intlPhoneInput) {
    intlPhoneInput.addEventListener('keyup', checkPhoneValidity);
  }
  if (codeInput) {
    codeInput.addEventListener('change', checkPhoneValidity);
  }
  checkPhoneValidity();
});
