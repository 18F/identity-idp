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
} = require('./document_capture_dom');

export const imageCaptureButtonClicked = (event) => {
  event.preventDefault();
  acuantImageCaptureStarted();

  const start = window.AcuantCamera.isCameraSupported
    ? window.AcuantCameraUI.start.bind(window.AcuantCameraUI)
    : window.AcuantCamera.startManualCapture.bind(window.AcuantCamera);

  start(
    {
      onCaptured() {},
      onCropped(response) {
        if (response) {
          acuantImageCaptureSuccess(response);
        } else {
          acuantImageCaptureFailed();
        }
      },
    },
    acuantImageCaptureFailed,
  );
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
