import { loadPolyfills } from '@18f/identity-polyfill';
import { PhoneInput } from '@18f/identity-phone-input';

loadPolyfills(['classlist', 'custom-event']).then(() => {
  const phoneInputs = document.querySelectorAll('.phone-input');
  phoneInputs.forEach((phoneInput) => new PhoneInput(phoneInput).bind());
});
