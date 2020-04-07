const acuantFallbackImageForm = () => document.querySelector('.acuant-fallback-image-form');

const acuantSdkUploadForm = () => document.querySelector('#acuant-sdk-upload-form');
const acuantSdkSpinner = () => document.querySelector('#acuant-sdk-spinner');
const acuantSdkContinueForm = () => document.querySelector('#acuant-sdk-continue-form');
const acuantSdkCaptureButton = () => document.querySelector('#acuant-sdk-capture');
const acuantSdkPreviewImage = () => document.querySelector('#acuant-sdk-preview');

const docAuthImageInput = () => document.querySelector('#doc_auth_image');
const docAuthImageDataUrlInput = () => document.querySelector('#doc_auth_image_data_url');

const hideAcuantSdkUIElements = () => {
  acuantSdkUploadForm().classList.add('hidden');
  acuantSdkSpinner().classList.add('hidden');
  acuantSdkContinueForm().classList.add('hidden');
};

const acuantImageCaptureSuccess = (response) => {
  hideAcuantSdkUIElements();
  acuantSdkPreviewImage().src = response.image.data;
  docAuthImageDataUrlInput().value = response.image.data;
  acuantSdkContinueForm().classList.remove('hidden');
};

const acuantImageCaptureFailure = (error) => {
  // TODO: Something here
  console.log('Acuant error: ', error);
};

const addAcuantCaptureButtonListener = () => {
  acuantSdkCaptureButton().addEventListener('click', (event) => {
    event.preventDefault();
    docAuthImageInput().required = false;
    hideAcuantSdkUIElements();
    acuantSdkSpinner().classList.remove('hidden');
    window.AcuantCameraUI.start(
      acuantImageCaptureSuccess,
      acuantImageCaptureFailure,
    );
  });
};

const initializeAcuantSdk = () => {
  window.AcuantJavascriptWebSdk.initialize(
    // Dummy credentials for Acuant frontend
    'aWRzY2FuZ293ZWJAYWN1YW50Y29ycC5jb206NVZLcm81Z0JEc1hrdFh2NA==',
    'https://services.assureid.net',
    {
      onSuccess: () => {
        hideAcuantSdkUIElements();
        addAcuantCaptureButtonListener();
        acuantSdkUploadForm().classList.remove('hidden');
      },
      onFail: () => {
        hideAcuantSdkUIElements();
        acuantFallbackImageForm().classList.remove('hidden');
      },
    },
  );
};

const loadAndInitializeAcuantSdk = () => {
  window.onAcuantSdkLoaded = initializeAcuantSdk;

  const sdk = document.createElement('script');
  sdk.src = 'AcuantJavascriptWebSdk.min.js';
  sdk.async = true;

  document.body.appendChild(sdk);
};

document.addEventListener('DOMContentLoaded', () => {
  acuantFallbackImageForm().classList.add('hidden');
  acuantSdkSpinner().classList.remove('hidden');
  loadAndInitializeAcuantSdk();
});
