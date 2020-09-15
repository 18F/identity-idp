import { loadAndInitializeAcuantSdk } from '../app/acuant/selfie_capture';
import { setDocumentCaptureFallbackTimeout } from '../app/acuant/document_capture_fallback';

document.addEventListener('DOMContentLoaded', () => {
  loadAndInitializeAcuantSdk();
});
