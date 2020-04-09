const {
  fetchSdkInitializationCredentials,
  fetchSdkInitializationEndpoint,
  acuantSdkInitializationStarted,
  acuantSdkInitializeSuccess,
  acuantSdkInitializeFailed,
  addClickEventListenerToAcuantCaptureButton,
  acuantImageCaptureStarted,
  acuantImageCaptureSuccess,
  acuantImageCaptureFailed,
} = require('./domUpdateCallbacks');

export const imageCaptureButtonClicked = (event) => {
  event.preventDefault();
  acuantImageCaptureStarted();
  window.AcuantCameraUI.start(
    acuantImageCaptureSuccess,
    acuantImageCaptureFailed,
  );
};

export const initializeAcuantSdk = (credentials = null, endpoint = null) => {
  credentials = credentials || fetchSdkInitializationCredentials();
  endpoint = endpoint || fetchSdkInitializationEndpoint();
  window.AcuantJavascriptWebSdk.initialize(
    // Dummy credentials for Acuant frontend
    credentials,
    endpoint,
    {
      onSuccess: () => {
        addClickEventListenerToAcuantCaptureButton(imageCaptureButtonClicked);
        acuantSdkInitializeSuccess();
      },
      onFail: acuantSdkInitializeFailed,
    },
  );
};

export const loadAndInitializeAcuantSdk = () => {
  acuantSdkInitializationStarted();
  window.onAcuantSdkLoaded = initializeAcuantSdk;

  const sdk = document.createElement('script');
  sdk.src = 'AcuantJavascriptWebSdk.min.js';
  sdk.async = true;

  document.body.appendChild(sdk);
};
