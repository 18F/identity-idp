import { loadPolyfills } from '@18f/identity-polyfill';

loadPolyfills(['custom-elements', 'classlist', 'custom-event'])
  .then(() => import('@18f/identity-phone-input'))
  .then(({ PhoneInput }) => customElements.define('lg-phone-input', PhoneInput));
