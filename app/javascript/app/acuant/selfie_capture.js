import {
  acuantSdkPreviewImage,
  imageDataUrlInput,
  imageFileInput,
  showAcuantSdkContainer,
} from './document_capture_dom';

const {
  fetchSdkInitializationCredentials,
  fetchSdkInitializationEndpoint,
  acuantSdkInitializationStarted,
  acuantSdkInitializeSuccess,
  acuantSdkInitializeFailed,
  addClickEventListenerToAcuantCaptureButton,
} = require('./document_capture_dom');

export const onCaptured = (image) => {
  acuantSdkPreviewImage().src = `data:image/jpeg;base64,${image}`;
  imageDataUrlInput().value = `data:image/jpeg;base64,${image}`;
  imageFileInput().required = false;
  showAcuantSdkContainer('continue-form');
};

export const imageCaptureButtonClicked = (event) => {
  event.preventDefault();
  window.AcuantPassiveLiveness.startSelfieCapture(onCaptured.bind(this));
};

export const initializeAcuantSdk = (credentials = null, endpoint = null) => {
  credentials = credentials || fetchSdkInitializationCredentials();
  endpoint = endpoint || fetchSdkInitializationEndpoint();
  window.AcuantJavascriptWebSdk.initialize(credentials, endpoint, {
    onSuccess: () => {
      addClickEventListenerToAcuantCaptureButton(imageCaptureButtonClicked);
      acuantSdkInitializeSuccess();
    },
    onFail: acuantSdkInitializeFailed,
  });
};

export const loadAndInitializeAcuantSdk = () => {
  acuantSdkInitializationStarted();
  window.onAcuantSdkLoaded = initializeAcuantSdk;

  const sdk = document.createElement('script');
  sdk.src = 'AcuantJavascriptWebSdk.min.js?v=11.4.1';
  sdk.async = true;

  document.body.appendChild(sdk);
};
