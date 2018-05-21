import { isValidNumber } from 'libphonenumber-js';

const isPhoneValid = (phone, countryCode) => {
  let phoneValid = isValidNumber(phone, countryCode);
  if (!phoneValid && countryCode === 'US') {
    phoneValid = isValidNumber(`+1 ${phone}`, countryCode);
  }
  return phoneValid;
};

const checkPhoneValidity = () => {
  const sendCodeButton = document.querySelector('[data-international-phone-form] input[name=commit]');
  const phoneInput = document.querySelector('[data-international-phone-form] .phone') || document.querySelector('[data-international-phone-form] .new-phone');
  const countryCodeInput = document.querySelector('[data-international-phone-form] .international-code');

  if (phoneInput && countryCodeInput && sendCodeButton) {
    const phone = phoneInput.value;
    const countryCode = countryCodeInput.value;

    const phoneValid = isPhoneValid(phone, countryCode);

    sendCodeButton.disabled = !phoneValid;

    if (!phoneValid) {
      phoneInput.dispatchEvent(new Event('invalid'));
    }
  }
};

document.addEventListener('DOMContentLoaded', () => {
  const intlPhoneInput = document.querySelector('[data-international-phone-form] .phone') || document.querySelector('[data-international-phone-form] .new-phone');
  const codeInput = document.querySelector('[data-international-phone-form] .international-code');
  if (intlPhoneInput) {
    intlPhoneInput.addEventListener('keyup', checkPhoneValidity);
  }
  if (codeInput) {
    codeInput.addEventListener('change', checkPhoneValidity);
  }
  checkPhoneValidity();
});
