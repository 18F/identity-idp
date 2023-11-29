import { DocumentCapturePolling } from '@18f/identity-document-capture-polling';

new DocumentCapturePolling({
  statusEndpoint: document
    .querySelector('[data-status-endpoint]')
    ?.getAttribute('data-status-endpoint') as string,
  elements: {
    backLink: document.querySelector('.link-sent-back-link') as HTMLAnchorElement,
    form: document.querySelector('.link-sent-continue-button-form') as HTMLFormElement,
  },
}).bind();
