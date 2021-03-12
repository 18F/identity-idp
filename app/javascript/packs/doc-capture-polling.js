import { loadPolyfills } from '@18f/identity-polyfill';
import { DocumentCapturePolling } from '@18f/identity-document-capture-polling';
import { getPageData } from '@18f/identity-page-data';

loadPolyfills(['fetch', 'classlist']).then(() => {
  new DocumentCapturePolling({
    statusEndpoint: /** @type {string} */ (getPageData('docCaptureStatusEndpoint')),
    elements: {
      backLink: /** @type {HTMLAnchorElement} */ (document.querySelector('.doc_capture_back_link')),
      form: /** @type {HTMLFormElement} */ (document.querySelector(
        '.doc_capture_continue_button_form',
      )),
    },
  }).bind();
});
