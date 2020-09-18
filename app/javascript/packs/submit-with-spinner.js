import { loadPolyfills } from '@18f/identity-polyfill';

loadPolyfills(['element-closest']).then(() => {
  const spinner = /** @type {HTMLDivElement} */ (document.getElementById('submit-spinner'));
  spinner.closest('form')?.addEventListener('submit', () => {
    spinner.className = '';
  });
});
