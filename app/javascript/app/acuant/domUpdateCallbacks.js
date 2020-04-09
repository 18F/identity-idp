// Fallback form elements
export const fallbackImageForm = () => document.querySelector('#acuant-fallback-image-form');
export const imageFileInput = () => document.querySelector('#doc_auth_image');
export const imageDataUrlInput = () => document.querySelector('#doc_auth_image_data_url');
// Acuant UI containers
export const acuantSdkUploadForm = () => document.querySelector('#acuant-sdk-upload-form');
export const acuantSdkSpinner = () => document.querySelector('#acuant-sdk-spinner');
export const acuantSdkContinueForm = () => document.querySelector('#acuant-sdk-continue-form');
// Acuant UI elements
export const acuantSdkCaptureButton = () => document.querySelector('#acuant-sdk-capture');
export const acuantSdkPreviewImage = () => document.querySelector('#acuant-sdk-preview');

const hideAcuantSdkContainers = () => {
  acuantSdkUploadForm().classList.add('hidden');
  acuantSdkSpinner().classList.add('hidden');
  acuantSdkContinueForm().classList.add('hidden');
};

export const acuantSdkInitializationStarted = () => {
  hideAcuantSdkContainers();
  fallbackImageForm().classList.add('hidden');
  acuantSdkSpinner().classList.remove('hidden');
};

export const acuantSdkInitializeSuccess = () => {
  hideAcuantSdkContainers();
  acuantSdkUploadForm().classList.remove('hidden');
};

export const acuantSdkInitializeFailed = () => {
  hideAcuantSdkContainers();
  fallbackImageForm().classList.remove('hidden');
};

export const addClickEventListenerToAcuantCaptureButton = (clickCallback) => {
  acuantSdkCaptureButton().onclick = clickCallback;
};

export const acuantImageCaptureStarted = () => {
  hideAcuantSdkContainers();
  acuantSdkSpinner().classList.remove('hidden');
};

export const acuantImageCaptureSuccess = (response) => {
  hideAcuantSdkContainers();
  acuantSdkPreviewImage().src = response.image.data;
  imageDataUrlInput().value = response.image.data;
  imageFileInput().required = false;
  acuantSdkContinueForm().classList.remove('hidden');
};

export const acuantImageCaptureFailed = (error) => {
  console.log('Acuant SDK image capture error:', error);
  hideAcuantSdkContainers();
  fallbackImageForm().classList.remove('hidden');
};
