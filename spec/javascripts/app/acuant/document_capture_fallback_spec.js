import sinon from 'sinon';

import {
  setupDocumentCaptureTestDOM,
  teardownDocumentCaptureTestDOM,
} from '../../support/acuant/document_capture_dom';

import {
  acuantSdkFallbackText,
  acuantSdkFallbackLink,
  acuantSdkUploadForm,
  acuantSdkSpinner,
  acuantSdkContinueForm,
  fallbackImageForm,
} from '../../../../app/javascript/app/acuant/document_capture_dom';

import {
  documentCaptureFallbackModeEnabled,
  documentCaptureFallbackLinkClicked,
  setDocumentCaptureFallbackTimeout,
} from '../../../../app/javascript/app/acuant/document_capture_fallback';

describe('acuant/document_capture_fallback', () => {
  beforeEach(() => {
    setupDocumentCaptureTestDOM();
  });

  afterEach(() => {
    teardownDocumentCaptureTestDOM();
  });

  describe('.documentCaptureFallbackLinkClicked', () => {
    it('hides all of the acuant containers and the help text and shows the fallback form', () => {
      const event = { preventDefault: sinon.spy() };

      documentCaptureFallbackLinkClicked(event);

      expect(event.preventDefault.calledOnce).to.eq(true);
      expect(acuantSdkUploadForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkSpinner().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkContinueForm().classList.contains('hidden')).to.eq(true);
      expect(acuantSdkFallbackText().classList.contains('hidden')).to.eq(true);
      expect(fallbackImageForm().classList.contains('hidden')).to.eq(false);
    });

    it('enables document capture fallback mode', () => {
      const event = { preventDefault: sinon.spy() };

      documentCaptureFallbackLinkClicked(event);

      expect(documentCaptureFallbackModeEnabled()).to.eq(true);
    });
  });

  describe('.setDocumentCaptureFallbackTimeout', () => {
    beforeEach(() => {
      window.setTimeout = sinon.spy();
    });

    it('adds a click listener to the fallback link', () => {
      setDocumentCaptureFallbackTimeout();

      expect(acuantSdkFallbackLink().onclick).to.eq(
        documentCaptureFallbackLinkClicked,
      );
    });

    it('shows the fallback help test after 5 seconds', () => {
      setDocumentCaptureFallbackTimeout();

      expect(window.setTimeout.calledOnce).to.eq(true);

      const { args } = window.setTimeout.lastCall;
      const callback = args[0];
      const timeout = args[1];

      expect(timeout).to.eq(5000);

      callback();

      expect(acuantSdkFallbackText().classList.contains('hidden')).to.eq(false);
    });
  });
});
