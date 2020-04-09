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
    'aWRzY2FuZ293ZWJAYWN1YW50Y29ycC5jb206NVZLcm81Z0JEc1hrdFh2NA==',
    'https://services.assureid.net',
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
