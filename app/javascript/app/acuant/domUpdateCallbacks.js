export const imageCaptureDomElements = {
  // Fallback form elements
  fallbackImageForm: document.querySelector('#acuant-fallback-image-form'),
  imageFileInput: document.querySelector('#doc_auth_image'),
  imageDataUrlInput: document.querySelector('#doc_auth_image_data_url'),
  // Acuant UI containers
  acuantSdkUploadForm: document.querySelector('#acuant-sdk-upload-form'),
  acuantSdkSpinner: document.querySelector('#acuant-sdk-spinner'),
  acuantSdkContinueForm: document.querySelector('#acuant-sdk-continue-form'),
  // Acuant UI elements
  acuantSdkCaptureButton: document.querySelector('#acuant-sdk-capture'),
  acuantSdkPreviewImage: document.querySelector('#acuant-sdk-preview'),
};

const hideAcuantSdkContainers = () => {
  imageCaptureDomElements.acuantSdkUploadForm.classList.add('hidden');
  imageCaptureDomElements.acuantSdkSpinner.classList.add('hidden');
  imageCaptureDomElements.acuantSdkContinueForm.classList.add('hidden');
};

export const acuantSdkInitializationStarted = () => {
  hideAcuantSdkContainers();
  imageCaptureDomElements.fallbackImageForm.classList.add('hidden');
  imageCaptureDomElements.acuantSdkSpinner.classList.remove('hidden');
};

export const acuantSdkInitializeSuccess = () => {
  hideAcuantSdkContainers();
  imageCaptureDomElements.acuantSdkUploadForm.classList.remove('hidden');
};

export const acuantSdkInitializeFailed = () => {
  hideAcuantSdkContainers();
  imageCaptureDomElements.fallbackImageForm.classList.remove('hidden');
};

export const addClickEventListenerToAcuantCaptureButton = (clickCallback) => {
  imageCaptureDomElements.acuantSdkCaptureButton.addEventListener('click', clickCallback);
};

export const acuantImageCaptureStarted = () => {
  hideAcuantSdkContainers();
  imageCaptureDomElements.acuantSdkSpinner.classList.remove('hidden');
};

export const acuantImageCaptureSuccess = (response) => {
  hideAcuantSdkContainers();
  imageCaptureDomElements.acuantSdkPreviewImage.src = response.image.data;
  imageCaptureDomElements.imageDataUrlInput.value = response.image.data;
  imageCaptureDomElements.imageFileInput.required = false;
  imageCaptureDomElements.acuantSdkContinueForm.classList.remove('hidden');
};

export const acuantImageCaptureFailed = (error) => {
  console.log('Acuant SDK image capture error:', error);
  hideAcuantSdkContainers();
  imageCaptureDomElements.fallbackImageForm.classList.remove('hidden');
};
