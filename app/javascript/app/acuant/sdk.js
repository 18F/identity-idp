const {
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

export const initializeAcuantSdk = () => {
  window.AcuantJavascriptWebSdk.initialize(
    // TODO: Move these into a meta tag or something
    // Dummy credentials for Acuant frontend
    window.ACUANT_SDK_INITIALIZATION_CREDS,
    window.ACUANT_SDK_INITIALIZATION_ENDPOINT,
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
