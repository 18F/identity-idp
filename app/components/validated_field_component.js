import { loadPolyfills } from '@18f/identity-polyfill';

loadPolyfills(['custom-elements', 'classlist'])
  .then(() => import('@18f/identity-validated-field'))
  .then(({ ValidatedField }) => customElements.define('lg-validated-field', ValidatedField));
