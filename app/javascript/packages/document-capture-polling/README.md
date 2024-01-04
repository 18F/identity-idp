# `@18f/identity-document-capture-polling`

Package implementing behaviors associated with the hybrid handoff document capture flow, where document capture is initiated on a desktop computer and completed on a mobile device. The behaviors of this package are responsible for polling for the result of a document capture happening on another device, and redirecting the user upon completion or failure.

## Usage

Initialize the package's binding with the polling endpoint and required elements:

```ts
import { DocumentCapturePolling } from '@18f/identity-document-capture-polling';

new DocumentCapturePolling({
  statusEndpoint: '/path/to/endpoint',
  elements: {
    backLink: document.querySelector('.link-sent-back-link'),
    form: document.querySelector('.link-sent-continue-button-form'),
  },
}).bind();
```

