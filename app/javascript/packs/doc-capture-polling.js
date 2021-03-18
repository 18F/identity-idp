import { loadPolyfills } from '@18f/identity-polyfill';
import { DocumentCapturePolling } from '@18f/identity-document-capture-polling';
import { getPageData } from '@18f/identity-page-data';

loadPolyfills(['fetch', 'classlist']).then(() => {
  new DocumentCapturePolling({
    statusEndpoint: /** @type {string} */ (getPageData('docCaptureStatusEndpoint')),
    elements: {
      form: /** @type {HTMLFormElement} */ (document.querySelector(
        '.doc_capture_continue_button_form',
      )),
    },
  }).bind();
});
