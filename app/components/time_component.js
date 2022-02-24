import { loadPolyfills } from '@18f/identity-polyfill';

loadPolyfills(['custom-elements'])
  .then(() => import('@18f/identity-time-element'))
  .then(({ TimeElement }) => customElements.define('lg-time', TimeElement));
