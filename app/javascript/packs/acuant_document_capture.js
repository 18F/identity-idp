import { loadAndInitializeAcuantSdk } from '../app/acuant/document_capture';
import { setDocumentCaptureFallbackTimeout } from '../app/acuant/document_capture_fallback';
import { createElement } from 'react';
import ReactDOM from 'react-dom';
import Test from '../app/acuant/document_capture_new';

document.addEventListener('DOMContentLoaded', () => {
  const reactContainer = document.getElementById('document-capture-form');
  if (reactContainer) {
    ReactDOM.render(createElement(Test), reactContainer);
  }
  loadAndInitializeAcuantSdk();
  setDocumentCaptureFallbackTimeout();
});
