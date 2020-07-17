// eslint-disable-next-line import/no-cycle
import { documentCaptureFallbackModeEnabled } from './document_capture_fallback';

// Fallback form elements
export const fallbackImageForm = () => document.querySelector('#acuant-fallback-image-form');
export const imageFileInput = () => document.querySelector('#doc_auth_image');
export const imageDataUrlInput = () => document.querySelector('#doc_auth_image_data_url');
// Acuant UI containers
export const acuantSdkUploadForm = () => document.querySelector('#acuant-sdk-upload-form');
export const acuantSdkSpinner = () => document.querySelector('#acuant-sdk-spinner');
export const acuantSdkCaptureView = () => document.querySelector('#acuant-sdk-capture-view');
export const acuantSdkCaptureViewCloseButton = () => document.querySelector('#acuant-sdk-capture-view-close');
export const acuantSdkContinueForm = () => document.querySelector('#acuant-sdk-continue-form');
// Acuant UI elements
export const acuantSdkCaptureButton = () => document.querySelector('#acuant-sdk-capture');
export const acuantSdkPreviewImage = () => document.querySelector('#acuant-sdk-preview');
// Fallback UI elements
export const acuantSdkFallbackText = () => document.querySelector('#acuant-fallback-text');
export const acuantSdkFallbackLink = () => document.querySelector('#acuant-fallback-link');

export const fetchSdkInitializationCredentials = () => document.querySelector('meta[name="acuant-sdk-initialization-creds"]').content;

export const fetchSdkInitializationEndpoint = () => document.querySelector('meta[name="acuant-sdk-initialization-endpoint"]').content;

const hideAcuantSdkContainers = () => {
  acuantSdkUploadForm().classList.add('hidden');
  acuantSdkSpinner().classList.add('hidden');
  acuantSdkCaptureView().classList.add('hidden');
  acuantSdkContinueForm().classList.add('hidden');
};

export const acuantImageCaptureEnded = () => {
  acuantSdkCaptureView().classList.add('hidden');
  acuantSdkUploadForm().classList.remove('hidden');
  window.AcuantCameraUI.end();
};

export const addClickEventListenerToAcuantCaptureViewCloseButton = (clickCallback) => {
  acuantSdkCaptureViewCloseButton().onclick = clickCallback;
};

const showFallbackForm = () => {
  fallbackImageForm().classList.remove('hidden');
};

export const showAcuantSdkContainer = (container) => {
  if (documentCaptureFallbackModeEnabled()) return;

  hideAcuantSdkContainers();

  switch (container) {
    case 'upload-form':
      acuantSdkUploadForm().classList.remove('hidden');
      break;
    case 'spinner':
      acuantSdkSpinner().classList.remove('hidden');
      break;
    case 'capture-view':
      addClickEventListenerToAcuantCaptureViewCloseButton(acuantImageCaptureEnded);
      acuantSdkCaptureView().classList.remove('hidden');
      break;
    case 'continue-form':
      acuantSdkContinueForm().classList.remove('hidden');
      break;
    default:
      break;
  }
};

export const acuantSdkInitializationStarted = () => {
  fallbackImageForm().classList.add('hidden');
  showAcuantSdkContainer('spinner');
};

export const acuantSdkInitializeSuccess = () => {
  showAcuantSdkContainer('upload-form');
};

export const acuantSdkInitializeFailed = () => {
  hideAcuantSdkContainers();
  showFallbackForm();
};

export const addClickEventListenerToAcuantCaptureButton = (clickCallback) => {
  acuantSdkCaptureButton().onclick = clickCallback;
};

export const acuantImageCaptureStarted = () => {
  showAcuantSdkContainer('capture-view');
};

export const acuantImageCaptureSuccess = (response) => {
  acuantSdkPreviewImage().src = response.image.data;
  imageDataUrlInput().value = response.image.data;
  imageFileInput().required = false;
  showAcuantSdkContainer('continue-form');
};

export const acuantImageCaptureFailed = (error) => {
  // eslint-disable-next-line
  console.log('Acuant SDK image capture error:', error);
  hideAcuantSdkContainers();
  showFallbackForm();
};

export const showAcuantSdkFallbackText = () => {
  acuantSdkFallbackText().classList.remove('hidden');
};

export const addClickEventListenerToAcuantFallbackLink = (clickCallback) => {
  acuantSdkFallbackLink().onclick = clickCallback;
};

export const acauntDocumentCaptureFallbackEnabled = () => {
  hideAcuantSdkContainers();
  showFallbackForm();
  acuantSdkFallbackText().classList.add('hidden');
};
