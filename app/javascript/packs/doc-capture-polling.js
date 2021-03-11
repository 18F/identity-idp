import { loadPolyfills } from '@18f/identity-polyfill';
import { DocumentCapturePolling } from '@18f/identity-document-capture-polling';

loadPolyfills(['fetch', 'classlist']).then(() => {
  new DocumentCapturePolling({
    form: /** @type {HTMLFormElement} */ (document.querySelector(
      '.doc_capture_continue_button_form',
    )),
    instructions: /** @type {HTMLParagraphElement} */ (document.querySelector(
      '#doc_capture_continue_instructions',
    )),
  }).bind();
});
