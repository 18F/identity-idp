import { loadPolyfills } from '@18f/identity-polyfill';

loadPolyfills(['custom-elements', 'clipboard'])
  .then(() => import('@18f/identity-clipboard-button'))
  .then(({ ClipboardButton }) => customElements.define('lg-clipboard-button', ClipboardButton));
