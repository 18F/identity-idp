import AcuantCapture, {
  AcuantDocumentType,
  getDecodedBase64ByteSize,
  getNormalizedAcuantCaptureFailureMessage,
  isAcuantCameraAccessFailure,
} from '@18f/identity-document-capture/components/acuant-capture';
import {
  AcuantContextProvider,
  AnalyticsContext,
  FailedCaptureAttemptsContextProvider,
} from '@18f/identity-document-capture';
import { createEvent, waitFor, screen } from '@testing-library/dom';

import DeviceContext from '@18f/identity-document-capture/context/device';
import { I18n } from '@18f/identity-i18n';
import { I18nContext } from '@18f/identity-react-i18n';
import { fireEvent } from '@testing-library/react';
import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { getFixtureFile } from '../../../support/file';
import { render, useAcuant } from '../../../support/document-capture';

const ACUANT_CAPTURE_SUCCESS_RESULT = {
  image: {
    data: 'data:image/png,',
    width: 1748,
    height: 1104,
  },
  cardType: AcuantDocumentType.ID,
  dpi: 519,
  moire: 99,
  moireraw: 99,
  glare: 100,
  sharpness: 100,
};

describe('getDecodedBase64ByteSize', () => {
  it('returns the decoded byte size', () => {
    const original = 'Hello World';
    const encoded = window.btoa(original);

    expect(getDecodedBase64ByteSize(encoded)).to.equal(original.length);
  });
});

describe('document-capture/components/acuant-capture', () => {
  const { initialize } = useAcuant();

  let validUpload;
  before(async () => {
    validUpload = await getFixtureFile('doc_auth_images/id-back.jpg');
  });

  /**
   * Uploads a file to the given input. Unlike `@testing-library/user-event`, this does not call any
   * click handlers associated with the input.
   *
   * @param {HTMLInputElement} input
   * @param {File} value
   */
  function uploadFile(input, value) {
    fireEvent(
      input,
      createEvent('input', input, {
        target: { files: [value] },
        bubbles: true,
        cancelable: false,
        composed: true,
      }),
    );

    fireEvent.change(input, {
      target: { files: [value] },
    });
  }

  /**
   * Mimics Drag Drop a file to the given input. Unlike `@testing-library/user-event`,
   *  this does not call any click handlers associated with the input.
   *
   * @param {HTMLInputElement} input
   * @param {File} value
   */
  function dragDropFile(input, value) {
    fireEvent(
      input,
      createEvent('input', input, {
        target: { files: [value] },
        bubbles: true,
        cancelable: false,
        composed: true,
      }),
    );

    fireEvent.drop(input, {
      target: { files: [value] },
    });
  }

  describe('getNormalizedAcuantCaptureFailureMessage', () => {
    beforeEach(() => {
      window.AcuantJavascriptWebSdk = {
        START_FAIL_CODE: 'start-fail-code',
        REPEAT_FAIL_CODE: 'repeat-fail-code',
        SEQUENCE_BREAK_CODE: 'sequence-break-code',
      };
    });

    afterEach(() => {
      delete window.AcuantJavascriptWebSdk;
    });

    [
      undefined,
      'Camera not supported.',
      'already started.',
      'Missing HTML elements.',
      new Error(),
      "Expected div with 'acuant-camera' id",
      'Live capture has previously failed and was called again. User was sent to manual capture.',
      'sequence-break',
    ].forEach((error) => {
      it('returns a string', () => {
        const message = getNormalizedAcuantCaptureFailureMessage(error);

        expect(message).to.be.a('string');
      });
    });
  });

  describe('isAcuantCameraAccessFailure', () => {
    it('returns false if not a camera access failure', () => {
      expect(isAcuantCameraAccessFailure('Camera not supported.')).to.be.false();
    });

    it('returns true if a camera access failure', () => {
      expect(isAcuantCameraAccessFailure(new Error())).to.be.true();
    });
  });

  context('mobile', () => {
    it('renders with assumed capture button support while acuant is not ready and on mobile', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      expect(getByText('doc_auth.buttons.take_picture')).to.be.ok();
    });

    it('cancels capture if assumed support is not actually supported once ready', async () => {
      const { container, getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      await userEvent.click(getByText('doc_auth.buttons.take_picture'));

      initialize({ isCameraSupported: false });

      expect(container.querySelector('.full-screen')).to.be.null();
    });

    it('renders with upload button as mobile-primary (secondary) button if acuant script fails to load', async () => {
      const { findByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="/gone.js" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      const button = await findByText('doc_auth.buttons.upload_picture');
      expect(button.classList.contains('usa-button--outline')).to.be.true();
      await userEvent.click(button);
    });

    it('renders without capture button if acuant fails to initialize', async () => {
      const { findByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize({ isSuccess: false });

      const button = await findByText('doc_auth.buttons.upload_picture');
      expect(button.classList.contains('usa-button--outline')).to.be.true();
    });

    it('renders a button when successfully loaded', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const button = getByText('doc_auth.buttons.take_picture');

      expect(button).to.be.ok();
    });

    it('renders a canvas when capturing', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
      expect(window.AcuantCameraUI.end.called).to.be.false();
    });

    it('does not start capturing if an acuant instance is already active', async () => {
      const { getByLabelText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="First Image" />
            <AcuantCapture label="Second Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      let onCropped;

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          onCropped = () => callbacks.onCropped(ACUANT_CAPTURE_SUCCESS_RESULT);
        }),
        end: sinon.stub(),
      });

      const firstInput = getByLabelText('First Image');
      const secondInput = getByLabelText('Second Image');
      fireEvent.click(firstInput);

      await waitFor(() => firstInput.getAttribute('aria-busy') === 'true');
      fireEvent.click(secondInput);

      expect(window.AcuantCameraUI.start).to.have.been.calledOnce();

      onCropped();
      await waitFor(() => firstInput.getAttribute('aria-busy') === 'false');
      await expect(window.window.AcuantCameraUI.end).to.eventually.be.called();

      fireEvent.click(secondInput);

      expect(window.AcuantCameraUI.start).to.have.been.calledTwice();
    });

    it('starts capturing when clicking input on supported device', () => {
      const { getByLabelText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const button = getByLabelText('Image');
      fireEvent.click(button);

      expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
      expect(window.AcuantCameraUI.end.called).to.be.false();
    });

    it('shows a generic error if camera starts but cropping error occurs', async () => {
      const trackEvent = sinon.spy();
      const { container, getByLabelText, findByText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture label="Image" name="test" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      initialize({
        // Call `onCropped` with a response of 'undefined'
        start: sinon.stub().callsArgWithAsync(1, undefined),
      });

      const button = getByLabelText('Image');
      await userEvent.click(button);
      // "Oops, something went wrong. Please try again."
      await findByText('errors.general');

      expect(window.AcuantCameraUI.end).to.have.been.calledOnce();
      expect(container.querySelector('.full-screen')).to.be.null();
      expect(trackEvent).to.have.been.calledWith('IdV: Image capture failed', {
        field: 'test',
        acuantCaptureMode: 'AUTO',
        error: 'Cropping failure',
        liveness_checking_required: false,
      });
      expect(document.activeElement).to.equal(button);
    });

    it('shows error if capture fails: latest version of Acuant SDK', async () => {
      const trackEvent = sinon.spy();
      const { container, getByLabelText, findByText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture label="Image" name="test" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      const start = async ({ onError }) => {
        await onError('Camera not supported.', 'start-fail-code');
      };

      initialize({
        start,
      });

      const button = getByLabelText('Image');
      await userEvent.click(button);

      await findByText('doc_auth.errors.camera.failed');
      expect(window.AcuantCameraUI.end).to.have.been.calledOnce();
      expect(container.querySelector('.full-screen')).to.be.null();
      expect(trackEvent).to.have.been.calledWith('IdV: Image capture failed', {
        field: 'test',
        acuantCaptureMode: 'AUTO',
        error: 'Camera not supported',
        liveness_checking_required: false,
      });
      expect(document.activeElement).to.equal(button);
    });

    it('shows sequence break error: latest version of SDK', async () => {
      const trackEvent = sinon.spy();
      const { container, getByLabelText, findByText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture label="Image" name="test" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      initialize({
        start: sinon.stub().callsFake((callbacks) => {
          const { onError } = callbacks;
          setTimeout(() => {
            const code = 'sequence-break-code';
            document.cookie = `AcuantCameraHasFailed=${code}`;
            onError('iOS 15 sequence break', code);
          }, 0);
        }),
      });

      const button = getByLabelText('Image');
      await userEvent.click(button);

      await findByText('doc_auth.errors.upload_error errors.messages.try_again');
      expect(window.AcuantCameraUI.end).to.have.been.calledOnce();
      expect(container.querySelector('.full-screen')).to.be.null();
      expect(trackEvent).to.have.been.calledWith('IdV: Image capture failed', {
        field: 'test',
        acuantCaptureMode: 'AUTO',
        error: 'iOS 15 GPU Highwater failure (SEQUENCE_BREAK_CODE)',
        liveness_checking_required: false,
      });
      await waitFor(() => document.activeElement === button);

      const defaultPrevented = !fireEvent.click(button);

      window.AcuantCameraUI.start.resetHistory();
      expect(defaultPrevented).to.be.false();
      expect(window.AcuantCameraUI.start.called).to.be.false();
    });

    it('calls onCameraAccessDeclined if camera access is declined: latest version of SDK', async () => {
      const trackEvent = sinon.spy();
      const onCameraAccessDeclined = sinon.stub();
      const { container, getByLabelText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture
                label="Image"
                name="test"
                onCameraAccessDeclined={onCameraAccessDeclined}
              />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      const start = async ({ onError }) => {
        await onError(new Error());
      };

      initialize({
        start,
      });

      const button = getByLabelText('Image');
      await userEvent.click(button);

      await Promise.all([
        expect(onCameraAccessDeclined).to.eventually.be.called(),
        expect(window.AcuantCameraUI.end).to.eventually.be.called(),
      ]);
      expect(container.querySelector('.full-screen')).to.be.null();
      expect(trackEvent).to.have.been.calledWith('IdV: Image capture failed', {
        field: 'test',
        acuantCaptureMode: 'AUTO',
        error: 'User or system denied camera access',
        liveness_checking_required: false,
      });
      expect(document.activeElement).to.equal(button);
    });

    it('blocks focus trap default focus return behavior if focus transitions during error', async () => {
      let outsideInput;
      const onCameraAccessDeclined = sinon.stub().callsFake(() => {
        outsideInput.focus();
      });
      const { container, getByLabelText, getByTestId } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <input data-testid="outside-input" />
            <AcuantCapture
              label="Image"
              name="test"
              onCameraAccessDeclined={onCameraAccessDeclined}
            />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );
      outsideInput = getByTestId('outside-input');

      const start = async ({ onError }) => {
        await onError(new Error());
      };

      initialize({
        start,
      });

      const button = getByLabelText('Image');
      await userEvent.click(button);

      await waitFor(() => document.activeElement === outsideInput);
      expect(container.classList.contains('full-screen')).to.be.false();
    });

    it('renders pending state while cropping', async () => {
      const { getByLabelText, getByText, container } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
        { isMockClient: false },
      );

      let onCropped;

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          onCropped = async () => {
            await Promise.resolve();
            callbacks.onCropped(ACUANT_CAPTURE_SUCCESS_RESULT);
          };
        }),
      });

      const input = getByLabelText('Image');
      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      await waitFor(() => !container.querySelector('.full-screen'));
      expect(input.getAttribute('aria-busy')).to.equal('true');

      onCropped();

      await waitFor(() => expect(input.getAttribute('aria-busy')).to.equal('false'));
    });

    it('calls onChange with the captured image on successful capture', async () => {
      const onChange = sinon.mock();
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider
            sdkSrc="about:blank"
            cameraSrc="about:blank"
            sharpnessThreshold={50}
            glareThreshold={50}
          >
            <AcuantCapture label="Image" onChange={onChange} />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          await Promise.resolve();
          callbacks.onCropped(ACUANT_CAPTURE_SUCCESS_RESULT);
        }),
      });

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      await expect(onChange).to.eventually.be.calledWith(
        'data:image/png,',
        sinon.match({
          assessment: 'success',
          documentType: 'id',
          dpi: sinon.match.number,
          glare: sinon.match.number,
          glareScoreThreshold: sinon.match.number,
          height: sinon.match.number,
          isAssessedAsBlurry: false,
          isAssessedAsGlare: false,
          mimeType: 'image/jpeg',
          moire: sinon.match.number,
          sharpness: sinon.match.number,
          sharpnessScoreThreshold: sinon.match.number,
          source: 'acuant',
          width: sinon.match.number,
          captureAttempts: sinon.match.number,
          size: sinon.match.number,
        }),
      );
      await expect(window.AcuantCameraUI.end).to.eventually.be.called();
    });

    it('ends the capture when the component unmounts', () => {
      const { getByText, unmount } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      unmount();

      expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
    });

    it('renders retry button when value and capture supported', async () => {
      const image = await getFixtureFile('doc_auth_images/id-front.jpg');
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" value={image} />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const button = getByText('doc_auth.buttons.take_picture_retry');
      expect(button).to.be.ok();

      await userEvent.click(button);
      expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
    });

    it('renders upload button when value and capture not supported', async () => {
      const onChange = sinon.stub();
      const onClick = sinon.spy();
      const { getByText, getByLabelText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" onChange={onChange} />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize({ isCameraSupported: false });

      const input = getByLabelText('Image');

      // Since file input prompt occurs by button click proxy to input, we must fire upload event
      // directly at the input. At least ensure that clicking button does "click" input.
      input.addEventListener('click', onClick);
      await userEvent.click(getByText('doc_auth.buttons.upload_picture'));
      expect(onClick).to.have.been.calledOnce();

      uploadFile(input, validUpload);
      await new Promise((resolve) => onChange.callsFake(resolve));
      expect(onChange).to.have.been.calledWith(
        validUpload,
        sinon.match({
          height: sinon.match.number,
          mimeType: 'image/jpeg',
          source: 'upload',
          width: sinon.match.number,
        }),
      );
    });

    it('onChange not called if allowUpload is false and user drags drops file', () => {
      const onChange = sinon.stub();
      const { getByLabelText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" onChange={onChange} allowUpload={false} />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize({ isCameraSupported: false });

      const input = getByLabelText('Image');
      dragDropFile(input, validUpload);
      expect(onChange).not.to.have.been.called();
    });

    it('renders error message and logs metadata if capture succeeds but the document type identified is unsupported', async () => {
      const trackEvent = sinon.spy();
      const { getByText, findByText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture label="Image" name="test" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          await Promise.resolve();
          callbacks.onCropped({
            ...ACUANT_CAPTURE_SUCCESS_RESULT,
            cardType: AcuantDocumentType.PASSPORT,
          });
        }),
      });

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      const error = await findByText('doc_auth.errors.general.fallback_field_level');

      expect(trackEvent).to.have.been.calledWith(
        'IdV: test image added',
        sinon.match({
          documentType: 'passport',
          isAssessedAsUnsupported: true,
          assessment: 'unsupported',
        }),
      );

      expect(error).to.be.ok();
    });

    it('renders error message if capture succeeds but photo glare exceeds threshold', async () => {
      const trackEvent = sinon.spy();
      const { getByText, findByText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider
              sdkSrc="about:blank"
              cameraSrc="about:blank"
              glareThreshold={50}
              sharpnessThreshold={50}
            >
              <AcuantCapture label="Image" name="test" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          await Promise.resolve();
          callbacks.onCropped({
            ...ACUANT_CAPTURE_SUCCESS_RESULT,
            glare: 49,
          });
        }),
      });

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      const error = await findByText('doc_auth.errors.glare.failed_short');
      expect(trackEvent).to.have.been.calledWith('IdV: test image added', {
        documentType: 'id',
        mimeType: 'image/jpeg',
        source: 'acuant',
        dpi: 519,
        moire: 99,
        glare: 49,
        height: 1104,
        sharpnessScoreThreshold: sinon.match.number,
        glareScoreThreshold: 50,
        isAssessedAsUnsupported: false,
        isAssessedAsBlurry: false,
        isAssessedAsGlare: true,
        assessment: 'glare',
        sharpness: 100,
        width: 1748,
        captureAttempts: sinon.match.number,
        selfie_attempts: sinon.match.number,
        size: sinon.match.number,
        acuantCaptureMode: 'AUTO',
        fingerprint: null,
        failedImageResubmission: false,
        liveness_checking_required: false,
      });

      expect(error).to.be.ok();
    });

    it('renders error message if capture succeeds but photo is too blurry', async () => {
      const trackEvent = sinon.spy();
      const { getByText, findByText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider
              sdkSrc="about:blank"
              cameraSrc="about:blank"
              sharpnessThreshold={50}
              glareThreshold={50}
            >
              <AcuantCapture label="Image" name="test" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          await Promise.resolve();
          callbacks.onCropped({
            ...ACUANT_CAPTURE_SUCCESS_RESULT,
            sharpness: 49,
          });
        }),
      });

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      const error = await findByText('doc_auth.errors.sharpness.failed_short');
      expect(trackEvent).to.have.been.calledWith('IdV: test image added', {
        documentType: 'id',
        mimeType: 'image/jpeg',
        source: 'acuant',
        dpi: 519,
        moire: 99,
        glare: 100,
        height: 1104,
        sharpnessScoreThreshold: 50,
        glareScoreThreshold: sinon.match.number,
        isAssessedAsUnsupported: false,
        isAssessedAsBlurry: true,
        isAssessedAsGlare: false,
        assessment: 'blurry',
        sharpness: 49,
        width: 1748,
        captureAttempts: sinon.match.number,
        selfie_attempts: sinon.match.number,
        size: sinon.match.number,
        acuantCaptureMode: sinon.match.string,
        fingerprint: null,
        failedImageResubmission: false,
        liveness_checking_required: false,
      });

      expect(error).to.be.ok();
    });

    it('shows at most one error message between AcuantCapture and FileInput', async () => {
      const { getByLabelText, getByText, findByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider
            sdkSrc="about:blank"
            cameraSrc="about:blank"
            sharpnessThreshold={50}
          >
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
        { isMockClient: false },
      );

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          await Promise.resolve();
          callbacks.onCropped({
            ...ACUANT_CAPTURE_SUCCESS_RESULT,
            sharpness: 49,
          });
        }),
      });

      const file = new window.File([''], 'upload.txt', { type: 'text/plain' });

      const input = getByLabelText('Image');
      uploadFile(input, file);

      expect(await findByText('doc_auth.errors.file_type.invalid')).to.be.ok();

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      expect(await findByText('doc_auth.errors.sharpness.failed_short')).to.be.ok();
      expect(() => getByText('doc_auth.errors.file_type.invalid')).to.throw();
    });

    it('removes error message once image is corrected', async () => {
      const trackEvent = sinon.spy();
      const { getByText, findByText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider
              sdkSrc="about:blank"
              cameraSrc="about:blank"
              sharpnessThreshold={50}
              glareThreshold={50}
            >
              <AcuantCapture label="Image" name="test" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      initialize({
        start: sinon
          .stub()
          .onFirstCall()
          .callsFake(async (callbacks) => {
            await Promise.resolve();
            callbacks.onCaptured();
            await Promise.resolve();
            callbacks.onCropped({
              ...ACUANT_CAPTURE_SUCCESS_RESULT,
              sharpness: 49,
            });
          })
          .onSecondCall()
          .callsFake(async (callbacks) => {
            await Promise.resolve();
            callbacks.onCaptured();
            await Promise.resolve();
            callbacks.onCropped(ACUANT_CAPTURE_SUCCESS_RESULT);
          }),
      });

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      const error = await findByText('doc_auth.errors.sharpness.failed_short');

      fireEvent.click(button);
      await waitFor(() => !error.textContent);
      expect(trackEvent).to.have.been.calledWith('IdV: test image added', {
        documentType: 'id',
        mimeType: 'image/jpeg',
        source: 'acuant',
        dpi: 519,
        moire: 99,
        glare: 100,
        height: 1104,
        sharpnessScoreThreshold: 50,
        glareScoreThreshold: sinon.match.number,
        isAssessedAsUnsupported: false,
        isAssessedAsBlurry: true,
        isAssessedAsGlare: false,
        assessment: 'blurry',
        sharpness: 49,
        width: 1748,
        captureAttempts: sinon.match.number,
        selfie_attempts: sinon.match.number,
        size: sinon.match.number,
        acuantCaptureMode: sinon.match.string,
        fingerprint: null,
        failedImageResubmission: false,
        liveness_checking_required: false,
      });
    });

    it('logs a human readable error when the document type errs', async () => {
      const trackEvent = sinon.spy();
      const incorrectCardType = 5;
      const { findByText, getByText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture label="Image" name="test" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          await Promise.resolve();
          callbacks.onCropped({ ...ACUANT_CAPTURE_SUCCESS_RESULT, cardType: incorrectCardType });
        }),
      });

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      await findByText('doc_auth.info.image_loading');

      expect(trackEvent).to.have.been.calledWith(
        'IdV: test image added',
        sinon.match({
          documentType: `An error in document type returned: ${incorrectCardType}`,
        }),
      );
    });

    it('triggers forced upload', () => {
      const { getByText } = render(
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'doc_auth.buttons.take_or_upload_picture_html': '<lg-upload>Upload</lg-upload>',
              },
            })
          }
        >
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture label="Image" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </I18nContext.Provider>,
      );

      initialize();

      const button = getByText('Upload');
      const defaultPrevented = !fireEvent.click(button);

      expect(defaultPrevented).to.be.false();
      expect(window.AcuantCameraUI.start.called).to.be.false();
    });

    it('optionally disallows upload', () => {
      const { getByText, getByLabelText } = render(
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'doc_auth.buttons.take_or_upload_picture_html': '<lg-upload>Upload</lg-upload>',
              },
            })
          }
        >
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture label="Image" allowUpload={false} />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </I18nContext.Provider>,
      );

      initialize();

      const input = getByLabelText('Image');
      const didClick = fireEvent.click(input);

      expect(() => getByText('Upload')).to.throw();
      expect(didClick).to.be.false();
      expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
      expect(() => getByText('doc_auth.tips.document_capture_hint')).to.throw();
    });

    it('does not show hint if capture is supported', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      expect(() => getByText('doc_auth.tips.document_capture_hint')).to.throw();
    });

    it('shows hint if capture is not supported', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize({ isSuccess: false });

      const hint = getByText('doc_auth.tips.document_capture_hint');

      expect(hint).to.be.ok();
    });
  });

  context('desktop', () => {
    it('does not render acuant capture canvas for environmental capture', async () => {
      const { getByLabelText } = render(
        <DeviceContext.Provider value={{ isMobile: false }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      await userEvent.click(getByLabelText('Image'));

      // It would be expected that if AcuantCaptureCanvas was rendered, an error would be thrown at
      // this point, since it references Acuant globals not loaded.
    });
  });

  context('mobile selfie', () => {
    const trackEvent = sinon.stub();
    const showSelfieHelp = sinon.stub();

    beforeEach(async () => {
      // Set up the components so that everything is as it would actually be -except- the AcuantSDK
      // The AcuantSDK isn't possible to run in test, so the initialize({...}) call below mocks it.
      render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture label="Image" name="selfie" showSelfieHelp={showSelfieHelp} isReady />
            </AcuantContextProvider>
          </AnalyticsContext.Provider>
        </DeviceContext.Provider>,
      );

      // Simulate the user clicking on the box that usually opens full screen selfie capture.
      // This isn't strictly necessary for the logging tests, but doing this makes the calls to
      // trackEvent appear in the actual order we'd expect when using the Acuant SDK.
      await userEvent.click(screen.getByLabelText('Image'));
    });

    it('renders the selfie capture loading div in acuant-capture', () => {
      // What we want to test is that the selfie version of the FileInput appears
      // when the name="selfie". The only difference between the selfie and document
      // versions is what happens when you click the FileInput, so this test clicks
      // the file input, then checks that the full screen div opened
      expect(screen.getByRole('dialog')).to.be.ok();
    });

    it('calls trackEvent from onSelfieCaptureOpen', () => {
      // In real use the `start` method opens the Acuant SDK full screen selfie capture window.
      // Because we can't do that in test (AcuantSDK does not allow), this doesn't attempt to load
      // the SDK. Instead, it simply calls the callback that happens when a photo is captured.
      // This allows us to test everything about that callback -except- the Acuant SDK parts.
      initialize({
        selfieStart: sinon.stub().callsFake((callbacks) => {
          callbacks.onOpened();
        }),
      });

      expect(trackEvent).to.be.calledWith('idv_selfie_image_clicked');
      expect(trackEvent).to.be.calledWith('IdV: Acuant SDK loaded');

      expect(trackEvent).to.have.been.calledWith('idv_sdk_selfie_image_capture_opened');
    });

    it('calls trackEvent from onSelfieCaptureClosed', () => {
      // In real use the `start` method opens the Acuant SDK full screen selfie capture window.
      // Because we can't do that in test (AcuantSDK does not allow), this doesn't attempt to load
      // the SDK. Instead, it simply calls the callback that happens when a photo is captured.
      // This allows us to test everything about that callback -except- the Acuant SDK parts.
      initialize({
        selfieStart: sinon.stub().callsFake((callbacks) => {
          callbacks.onClosed();
        }),
      });

      expect(trackEvent).to.be.calledWith('idv_selfie_image_clicked');
      expect(trackEvent).to.be.calledWith('IdV: Acuant SDK loaded');

      expect(trackEvent).to.have.been.calledWith(
        'idv_sdk_selfie_image_capture_closed_without_photo',
      );
    });

    it('calls showSelfieHelp from onSelfieCaptureClosed', () => {
      initialize({
        selfieStart: sinon.stub().callsFake((callbacks) => {
          callbacks.onClosed();
        }),
      });

      expect(showSelfieHelp).to.have.been.called();
    });

    it('calls trackEvent from onSelfieCaptureSuccess', () => {
      // In real use the `start` method opens the Acuant SDK full screen selfie capture window.
      // Because we can't do that in test (AcuantSDK does not allow), this doesn't attempt to load
      // the SDK. Instead, it simply calls the callback that happens when a photo is captured.
      // This allows us to test everything about that callback -except- the Acuant SDK parts.
      initialize({
        selfieStart: sinon.stub().callsFake((callbacks) => {
          callbacks.onCaptured();
        }),
      });

      expect(trackEvent).to.be.calledWith('idv_selfie_image_clicked');
      expect(trackEvent).to.be.calledWith('IdV: Acuant SDK loaded');

      expect(trackEvent).to.have.been.calledWith(
        'idv_selfie_image_added',
        sinon.match({
          captureAttempts: sinon.match.number,
          selfie_attempts: sinon.match.number,
        }),
      );
    });

    it('calls trackEvent from onSelfieRetake', () => {
      // In real use the `start` method opens the Acuant SDK full screen selfie capture window.
      // Because we can't do that in test (AcuantSDK does not allow), this doesn't attempt to load
      // the SDK. Instead, it simply calls the callback that happens when a photo is captured.
      // This allows us to test everything about that callback -except- the Acuant SDK parts.
      initialize({
        selfieStart: sinon.stub().callsFake((callbacks) => {
          callbacks.onPhotoRetake();
        }),
      });

      expect(trackEvent).to.be.calledWith('idv_selfie_image_clicked');
      expect(trackEvent).to.be.calledWith('IdV: Acuant SDK loaded');
      expect(trackEvent).to.be.calledWith(
        'idv_sdk_selfie_image_re_taken',
        sinon.match({
          captureAttempts: sinon.match.number,
          selfie_attempts: sinon.match.number,
        }),
      );
    });

    it('calls trackEvent from onSelfieTake', () => {
      // In real use the `start` method opens the Acuant SDK full screen selfie capture window.
      // Because we can't do that in test (AcuantSDK does not allow), this doesn't attempt to load
      // the SDK. Instead, it simply calls the callback that happens when a photo is captured.
      // This allows us to test everything about that callback -except- the Acuant SDK parts.
      initialize({
        selfieStart: sinon.stub().callsFake((callbacks) => {
          callbacks.onPhotoTaken();
        }),
      });

      expect(trackEvent).to.be.calledWith('idv_selfie_image_clicked');
      expect(trackEvent).to.be.calledWith('IdV: Acuant SDK loaded');
      expect(trackEvent).to.be.calledWith(
        'idv_sdk_selfie_image_taken',
        sinon.match({
          captureAttempts: sinon.match.number,
          selfie_attempts: sinon.match.number,
        }),
      );
    });

    it('calls trackEvent from onSelfieCaptureFailure', () => {
      const errorHash = { code: 1, message: 'Camera permission not granted' };

      // In real use the `start` method opens the Acuant SDK full screen selfie capture window.
      // Because we can't do that in test (AcuantSDK does not allow), this doesn't attempt to load
      // the SDK. Instead, it simply calls the callback that happens when a photo is captured.
      // This allows us to test everything about that callback -except- the Acuant SDK parts.
      initialize({
        selfieStart: sinon.stub().callsFake((callbacks) => {
          callbacks.onError(errorHash);
        }),
      });

      expect(trackEvent).to.be.calledWith('idv_selfie_image_clicked');
      expect(trackEvent).to.be.calledWith('IdV: Acuant SDK loaded');

      expect(trackEvent).to.have.been.calledWith(
        'idv_sdk_selfie_image_capture_failed',
        sinon.match({
          sdk_error_code: sinon.match.number,
          sdk_error_message: sinon.match.string,
        }),
      );
    });

    it('calls trackEvent from onImageCaptureInitialized', () => {
      // In real use the `start` method opens the Acuant SDK full screen selfie capture window.
      // Because we can't do that in test (AcuantSDK does not allow), this doesn't attempt to load
      // the SDK. Instead, it simply calls the callback that happens when a photo is captured.
      // This allows us to test everything about that callback -except- the Acuant SDK parts.
      initialize({
        selfieStart: sinon.stub().callsFake((callbacks) => {
          callbacks.onDetectorInitialized();
        }),
      });

      expect(trackEvent).to.be.calledWith('idv_selfie_image_clicked');
      expect(trackEvent).to.be.calledWith('IdV: Acuant SDK loaded');

      expect(trackEvent).to.have.been.calledWith(
        'idv_sdk_selfie_image_capture_initialized',
        sinon.match({
          captureAttempts: sinon.match.number,
          selfie_attempts: sinon.match.number,
        }),
      );
    });
  });

  it('optionally disallows upload', () => {
    const { getByText } = render(
      <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
        <AcuantCapture label="Image" allowUpload={false} />
      </AcuantContextProvider>,
    );

    expect(() => getByText('doc_auth.tips.document_capture_hint')).to.throw();
  });

  it('renders with custom className', () => {
    const { container } = render(<AcuantCapture label="File" className="my-custom-class" />);

    expect(container.firstChild.classList.contains('my-custom-class')).to.be.true();
  });

  it('clears a selected value', async () => {
    const image = await getFixtureFile('doc_auth_images/id-front.jpg');
    const onChange = sinon.spy();
    const { getByLabelText } = render(
      <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
        <AcuantCapture label="Image" value={image} onChange={onChange} />
      </AcuantContextProvider>,
    );

    const input = getByLabelText('Image');
    fireEvent.change(input, { target: { files: [] } });

    expect(onChange).to.have.been.calledWith(null, undefined);
  });

  it('restricts accepted file types', () => {
    const { getByLabelText } = render(
      <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
        <AcuantCapture label="Image" />
      </AcuantContextProvider>,
      { isMockClient: false },
    );

    const input = getByLabelText('Image');

    expect(input.getAttribute('accept')).to.equal('image/jpeg,image/png');
  });

  it('logs metrics for manual upload', async () => {
    const trackEvent = sinon.stub();
    const onChange = sinon.stub();

    const { getByLabelText } = render(
      <AnalyticsContext.Provider value={{ trackEvent }}>
        <FailedCaptureAttemptsContextProvider
          maxCaptureAttemptsBeforeNativeCamera={3}
          maxSubmissionAttemptsBeforeNativeCamera={3}
        >
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" name="front" onChange={onChange} />
          </AcuantContextProvider>
        </FailedCaptureAttemptsContextProvider>
      </AnalyticsContext.Provider>,
    );
    const input = getByLabelText('Image');
    uploadFile(input, validUpload);
    onChange.calls;
    await new Promise((resolve) => onChange.callsFake(resolve));
    expect(trackEvent).to.be.calledOnce();
    expect(trackEvent).to.have.been.calledWith(
      'IdV: front image added',
      sinon.match({
        width: sinon.match.number,
        height: sinon.match.number,
        fingerprint: sinon.match.string,
        source: 'upload',
        mimeType: 'image/jpeg',
        size: sinon.match.number,
        captureAttempts: sinon.match.number,
        acuantCaptureMode: null,
        liveness_checking_required: false,
      }),
    );
  });

  it('logs metrics for failed reupload', async () => {
    const trackEvent = sinon.stub();
    const onChange = sinon.stub();
    const { getByLabelText } = render(
      <AnalyticsContext.Provider value={{ trackEvent }}>
        <FailedCaptureAttemptsContextProvider
          failedFingerprints={{ front: ['kgLjncfQAICyEYQhdFMAAKxdFceQ80WPjwK2puuuLd8'], back: [] }}
          maxCaptureAttemptsBeforeNativeCamera={3}
          maxSubmissionAttemptsBeforeNativeCamera={3}
        >
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCapture label="Image" name="front" onChange={onChange} />
          </AcuantContextProvider>
        </FailedCaptureAttemptsContextProvider>
      </AnalyticsContext.Provider>,
    );
    const input = getByLabelText('Image');
    uploadFile(input, validUpload);
    onChange.calls;
    await new Promise((resolve) => onChange.callsFake(resolve));
    expect(trackEvent).to.be.calledOnce();
    expect(trackEvent).to.be.eventually.calledWith(
      'IdV: failed front image resubmitted',
      sinon.match({
        width: sinon.match.number,
        height: sinon.match.number,
        fingerprint: sinon.match.string,
        source: 'upload',
        mimeType: 'image/jpeg',
        size: sinon.match.number,
        captureAttempts: sinon.match.number,
        acuantCaptureMode: 'AUTO',
      }),
    );
  });

  it('logs clicks', async () => {
    const trackEvent = sinon.stub();
    const { getByText, getByLabelText } = render(
      <I18nContext.Provider
        value={
          new I18n({
            strings: {
              'doc_auth.buttons.take_or_upload_picture_html': '<lg-upload>Upload</lg-upload>',
            },
          })
        }
      >
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <AcuantCapture label="Image" name="test" />
            </AcuantContextProvider>
          </AnalyticsContext.Provider>
        </DeviceContext.Provider>
      </I18nContext.Provider>,
    );

    const placeholder = getByLabelText('Image');
    await userEvent.click(placeholder);
    await userEvent.click(getByLabelText('account.navigation.close'));
    const button = getByText('doc_auth.buttons.take_picture');
    await userEvent.click(button);
    await userEvent.click(getByLabelText('account.navigation.close'));
    const upload = getByText('Upload');
    fireEvent.click(upload);

    expect(trackEvent.callCount).to.be.at.least(3);
    expect(trackEvent).to.have.been.calledWith('IdV: test image clicked', {
      click_source: 'placeholder',
      isDrop: false,
      liveness_checking_required: false,
      captureAttempts: 1,
    });
    expect(trackEvent).to.have.been.calledWith('IdV: test image clicked', {
      click_source: 'button',
      isDrop: false,
      liveness_checking_required: false,
      captureAttempts: 1,
    });
    expect(trackEvent).to.have.been.calledWith('IdV: test image clicked', {
      click_source: 'button',
      isDrop: false,
      liveness_checking_required: false,
      captureAttempts: 1,
    });
  });

  it('logs drag-and-drop as click interaction', () => {
    const trackEvent = sinon.stub();
    const { getByLabelText } = render(
      <AnalyticsContext.Provider value={{ trackEvent }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <AcuantCapture label="Image" name="test" />
        </AcuantContextProvider>
      </AnalyticsContext.Provider>,
    );

    const input = getByLabelText('Image');
    fireEvent.drop(input);

    expect(trackEvent).to.have.been.calledWith('IdV: test image clicked', {
      click_source: 'placeholder',
      isDrop: true,
      liveness_checking_required: false,
      captureAttempts: 1,
    });
  });

  it('logs attempts', async () => {
    const trackEvent = sinon.stub();
    const { getByLabelText } = render(
      <AnalyticsContext.Provider value={{ trackEvent }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <AcuantCapture label="Image" name="test" />
        </AcuantContextProvider>
      </AnalyticsContext.Provider>,
    );

    const input = getByLabelText('Image');
    uploadFile(input, validUpload);

    await expect(trackEvent).to.eventually.be.calledWith(
      'IdV: test image added',
      sinon.match({ captureAttempts: 1 }),
    );

    uploadFile(input, validUpload);

    await expect(trackEvent).to.eventually.be.calledWith(
      'IdV: test image added',
      sinon.match({ captureAttempts: 2 }),
    );
  });
});
