import { JSDOM } from 'jsdom';
import sinon from 'sinon';

import {
  imageCaptureButtonClicked,
  initializeAcuantSdk,
  loadAndInitializeAcuantSdk,
} from '../../../../app/javascript/app/acuant/sdk';

import {
  fallbackImageForm,
  imageFileInput,
  imageDataUrlInput,
  acuantSdkUploadForm,
  acuantSdkSpinner,
  acuantSdkContinueForm,
  acuantSdkCaptureButton,
  acuantSdkPreviewImage,
} from '../../../../app/javascript/app/acuant/domUpdateCallbacks';

describe('acuant/sdk', () => {
  // This is the initial HTML on the page pulled from
  const INITIAL_HTML = `
    <input type='hidden' id='doc_auth_image_data_url'>

    <div id='acuant-fallback-image-form'>
      <input type='file' id='doc_auth_image' required>
      <input type='submit' value='continue' class='btn btn-primary'>
    </div>

    <div id='acuant-sdk-upload-form' class='hidden'>
      <button id='acuant-sdk-capture' class='btn btn-primary'>Choose image</button>
    </div>

    <div id='acuant-sdk-spinner' class='hidden'>
      <img src='wait.gif' width=50 height=50>
    </div>

    <div id='acuant-sdk-continue-form' class='hidden'>
      <img id='acuant-sdk-preview'>
      <input type='submit' value='Continue' class='btn btn-primary btn-wide mt2'>
    </div>
  `;

  beforeEach(() => {
    const dom = new JSDOM(INITIAL_HTML);
    global.window = dom.window;
    global.document = global.window.document;
    global.window.ACUANT_SDK_INITIALIZATION_CREDS = 'test creds';
    global.window.ACUANT_SDK_INITIALIZATION_ENDPOINT = 'test endpoint';
  });

  after(() => {
    global.window = undefined;
    global.document = undefined;
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
      initializeAcuantSdk();

      const initializeSpy = window.AcuantJavascriptWebSdk.initialize;

      expect(initializeSpy.calledOnce).to.eq(true);
      expect(initializeSpy.lastCall.args[0]).to.eq('test creds');
      expect(initializeSpy.lastCall.args[1]).to.eq('test endpoint');
    });

    it('shows the acuant sdk form when successful', () => {
      initializeAcuantSdk();
      const successCallback = window.AcuantJavascriptWebSdk.initialize.lastCall.args[2].onSuccess;
      successCallback();

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(false);
    });

    it('adds an event listener to the capture button when successful', () => {
      initializeAcuantSdk();
      const successCallback = window.AcuantJavascriptWebSdk.initialize.lastCall.args[2].onSuccess;
      successCallback();

      expect(acuantSdkCaptureButton().onclick).to.eq(imageCaptureButtonClicked);
    });

    it('shows the fallback form when failed', () => {
      initializeAcuantSdk();
      const failCallback = window.AcuantJavascriptWebSdk.initialize.lastCall.args[2].onFail;
      failCallback();

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(false);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
    });
  });

  describe('.imageCaptureButtonClicked', () => {
    let event = { preventDefault: () => {} };

    beforeEach(() => {
      window.AcuantCameraUI = { start: sinon.spy() };

      fallbackImageForm().classList.add('hidden');
      acuantSdkUploadForm().classList.remove('hidden');
      acuantSdkSpinner().classList.add('hidden');
      acuantSdkContinueForm().classList.add('hidden');
    });

    it('shows the spinner', () => {
      imageCaptureButtonClicked(event);

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(false);
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
      expect(acuantSdkContinueForm().classList.contains('hidden')).to.eq(false);

      expect(imageFileInput().required).to.eq(false);
      expect(imageDataUrlInput().value).to.eq('abc123');
      expect(acuantSdkPreviewImage().src).to.eq('abc123');
    });

    it('renders the fallback from when failed', () => {
      const error = 'This is a test Acuant error';

      imageCaptureButtonClicked(event);

      const failureCallback = window.AcuantCameraUI.start.lastCall.args[1];
      failureCallback(error);

      expect(fallbackImageForm().classList.contains('hidden')).to.eq(false);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkContinueForm().classList.contains('hidden')).to.eq(true);

      expect(imageFileInput().required).to.eq(true);
      expect(imageDataUrlInput().value).to.eq('');
      expect(acuantSdkPreviewImage().src).to.eq('');
    });
  });
});
