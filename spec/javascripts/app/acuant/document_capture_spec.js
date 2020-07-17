import sinon from 'sinon';

import {
  setupDocumentCaptureTestDOM,
  teardownDocumentCaptureTestDOM,
} from '../../support/acuant/document_capture_dom';

import { documentCaptureFallbackLinkClicked } from '../../../../app/javascript/app/acuant/document_capture_fallback';

import {
  fallbackImageForm,
  imageFileInput,
  imageDataUrlInput,
  acuantSdkUploadForm,
  acuantSdkSpinner,
  acuantSdkCaptureView,
  acuantSdkCaptureViewCloseButton,
  acuantSdkContinueForm,
  acuantSdkCaptureButton,
  acuantSdkPreviewImage,
  hideAcuantSdkCaptureView,
} from '../../../../app/javascript/app/acuant/document_capture_dom';

import {
  imageCaptureButtonClicked,
  initializeAcuantSdk,
  loadAndInitializeAcuantSdk,
} from '../../../../app/javascript/app/acuant/document_capture';

describe('acuant/document_capture', () => {
  beforeEach(() => {
    setupDocumentCaptureTestDOM();
  });

  after(() => {
    teardownDocumentCaptureTestDOM();
  });

  describe('.loadAndInitializeAcuantSdk', () => {
    it('hides the fallback form and shows the spinner and sets the initalization callback', () => {
      loadAndInitializeAcuantSdk();

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(false);
    });

    it('sets the sdk loaded callback and adds the script to document', () => {
      window.onAcuantSdkLoaded = undefined;

      loadAndInitializeAcuantSdk();

      const script = document.querySelector('script');
      expect(script.src).to.eq('AcuantJavascriptWebSdk.min.js');
      expect(script.async).to.eq(true);
      expect(window.onAcuantSdkLoaded).to.eq(initializeAcuantSdk);
    });
  });

  describe('.initializeAcuantSdk', () => {
    beforeEach(() => {
      window.AcuantJavascriptWebSdk = { initialize: sinon.spy() };
      fallbackImageForm().classList.add('hidden');
      acuantSdkSpinner().classList.remove('hidden');
    });

    it('initializes the Acuant SDK with the endpoint and creds', () => {
      initializeAcuantSdk('test creds', 'test endpoint');

      const initializeSpy = window.AcuantJavascriptWebSdk.initialize;

      expect(initializeSpy.calledOnce).to.eq(true);
      expect(initializeSpy.lastCall.args[0]).to.eq('test creds');
      expect(initializeSpy.lastCall.args[1]).to.eq('test endpoint');
    });

    it('shows the acuant upload form when successful', () => {
      initializeAcuantSdk('test creds', 'test endpoint');
      const successCallback = window.AcuantJavascriptWebSdk.initialize.lastCall.args[2].onSuccess;
      successCallback();

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkCaptureView().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(false);
    });

    it('adds an event listener to the capture button when successful', () => {
      initializeAcuantSdk('test creds', 'test endpoint');
      const successCallback = window.AcuantJavascriptWebSdk.initialize.lastCall.args[2].onSuccess;
      successCallback();

      expect(acuantSdkCaptureButton().onclick).to.eq(imageCaptureButtonClicked);
    });

    it('does not show the upload form when successful if in fallback mode', () => {
      initializeAcuantSdk('test creds', 'test endpoint');

      documentCaptureFallbackLinkClicked({ preventDefault: () => {} });

      const successCallback = window.AcuantJavascriptWebSdk.initialize.lastCall.args[2].onSuccess;
      successCallback();

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(false);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
    });

    it('shows the fallback form when failed', () => {
      initializeAcuantSdk('test creds', 'test endpoint');
      const failCallback = window.AcuantJavascriptWebSdk.initialize.lastCall.args[2].onFail;
      failCallback();

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(false);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkCaptureView().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
    });
  });

  describe('.imageCaptureButtonClicked', () => {
    const event = { preventDefault: () => {} };

    beforeEach(() => {
      window.AcuantCameraUI = { start: sinon.spy() };

      fallbackImageForm().classList.add('hidden');
      acuantSdkUploadForm().classList.remove('hidden');
      acuantSdkSpinner().classList.add('hidden');
      acuantSdkContinueForm().classList.add('hidden');
    });

    it('shows the image capture view', () => {
      imageCaptureButtonClicked(event);

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkCaptureView().classList.contains('hidden')).to.eq(false);
      expect(acuantSdkContinueForm().classList.contains('hidden')).to.eq(true);
    });

    it('starts the acuant camera UI capture experience', () => {
      imageCaptureButtonClicked(event);

      expect(window.AcuantCameraUI.start.calledOnce).to.eq(true);
    });

    it('prepares the form to be submitted when successful', () => {
      const response = { image: { data: 'abc123' } };

      imageCaptureButtonClicked(event);

      const successCallback = window.AcuantCameraUI.start.lastCall.args[0];
      successCallback(response);

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkCaptureView().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkContinueForm().classList.contains('hidden')).to.eq(false);

      expect(imageFileInput().required).to.eq(false);
      expect(imageDataUrlInput().value).to.eq('abc123');
      expect(acuantSdkPreviewImage().src).to.eq('abc123');
    });

    it('does not show the upload form when successful if in fallback mode', () => {
      const response = { image: { data: 'abc123' } };

      imageCaptureButtonClicked(event);
      documentCaptureFallbackLinkClicked(event);

      const successCallback = window.AcuantCameraUI.start.lastCall.args[0];
      successCallback(response);

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(false);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
    });

    it('renders the fallback from when failed', () => {
      const error = 'This is a test Acuant error';

      imageCaptureButtonClicked(event);

      const failureCallback = window.AcuantCameraUI.start.lastCall.args[1];
      failureCallback(error);

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(false);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkCaptureView().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkContinueForm().classList.contains('hidden')).to.eq(true);

      expect(imageFileInput().required).to.eq(true);
      expect(imageDataUrlInput().value).to.eq('');
      expect(acuantSdkPreviewImage().src).to.eq('');
    });

    it('adds an event listener to the close capture view button when initialized', () => {
      imageCaptureButtonClicked(event);

      expect(acuantSdkCaptureViewCloseButton().onclick).to.eq(hideAcuantSdkCaptureView);
    });
  });
});
