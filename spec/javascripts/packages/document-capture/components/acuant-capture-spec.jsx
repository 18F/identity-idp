import sinon from 'sinon';
import { fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { waitFor, createEvent } from '@testing-library/dom';
import AcuantCapture, {
  isAcuantCameraAccessFailure,
  getNormalizedAcuantCaptureFailureMessage,
  getDecodedBase64ByteSize,
} from '@18f/identity-document-capture/components/acuant-capture';
import { AcuantContextProvider, AnalyticsContext } from '@18f/identity-document-capture';
import DeviceContext from '@18f/identity-document-capture/context/device';
import { I18nContext } from '@18f/identity-react-i18n';
import { I18n } from '@18f/identity-i18n';
import { render, useAcuant } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

const ACUANT_CAPTURE_SUCCESS_RESULT = {
  image: {
    data: 'data:image/png,',
    width: 1748,
    height: 1104,
  },
  cardType: 1,
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

    it('shows error if capture fails', async () => {
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
        start: sinon.stub().callsArgWithAsync(1, 'Camera not supported.', 'start-fail-code'),
      });

      const button = getByLabelText('Image');
      await userEvent.click(button);

      await findByText('doc_auth.errors.camera.failed');
      expect(window.AcuantCameraUI.end).to.have.been.calledOnce();
      expect(container.querySelector('.full-screen')).to.be.null();
      expect(trackEvent).to.have.been.calledWith('IdV: Image capture failed', {
        field: 'test',
        error: 'Camera not supported',
      });
      expect(document.activeElement).to.equal(button);
    });

    it('shows sequence break error', async () => {
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
        start: sinon.stub().callsFake((_callbacks, onError) => {
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
        error: 'iOS 15 GPU Highwater failure (SEQUENCE_BREAK_CODE)',
      });
      await waitFor(() => document.activeElement === button);

      const defaultPrevented = !fireEvent.click(button);

      window.AcuantCameraUI.start.resetHistory();
      expect(defaultPrevented).to.be.false();
      expect(window.AcuantCameraUI.start.called).to.be.false();
    });

    it('calls onCameraAccessDeclined if camera access is declined', async () => {
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

      initialize({
        start: sinon.stub().callsArgWithAsync(1, new Error()),
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
        error: 'User or system denied camera access',
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

      initialize({
        start: sinon.stub().callsArgWithAsync(1, new Error()),
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
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
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
          attempt: sinon.match.number,
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

    it('renders error message if capture succeeds but photo glare exceeds threshold', async () => {
      const trackEvent = sinon.spy();
      const { getByText, findByText } = render(
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank" glareThreshold={50}>
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
        isAssessedAsBlurry: false,
        isAssessedAsGlare: true,
        assessment: 'glare',
        sharpness: 100,
        width: 1748,
        attempt: sinon.match.number,
        size: sinon.match.number,
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
        isAssessedAsBlurry: true,
        isAssessedAsGlare: false,
        assessment: 'blurry',
        sharpness: 49,
        width: 1748,
        attempt: sinon.match.number,
        size: sinon.match.number,
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
        isAssessedAsBlurry: true,
        isAssessedAsGlare: false,
        assessment: 'blurry',
        sharpness: 49,
        width: 1748,
        attempt: sinon.match.number,
        size: sinon.match.number,
      });
    });

    it('triggers forced upload', () => {
      const { getByText } = render(
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'doc_auth.buttons.take_or_upload_picture': '<lg-upload>Upload</lg-upload>',
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
                'doc_auth.buttons.take_or_upload_picture': '<lg-upload>Upload</lg-upload>',
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
    const { getByLabelText } = render(
      <AnalyticsContext.Provider value={{ trackEvent }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <AcuantCapture label="Image" name="test" />
        </AcuantContextProvider>
      </AnalyticsContext.Provider>,
    );

    const input = getByLabelText('Image');
    uploadFile(input, validUpload);

    await expect(trackEvent).to.eventually.be.calledWith('IdV: test image added', {
      height: sinon.match.number,
      mimeType: 'image/jpeg',
      source: 'upload',
      width: sinon.match.number,
      attempt: sinon.match.number,
      size: sinon.match.number,
    });
  });

  it('logs clicks', async () => {
    const trackEvent = sinon.stub();
    const { getByText, getByLabelText } = render(
      <I18nContext.Provider
        value={
          new I18n({
            strings: { 'doc_auth.buttons.take_or_upload_picture': '<lg-upload>Upload</lg-upload>' },
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
    await userEvent.click(getByLabelText('users.personal_key.close'));
    const button = getByText('doc_auth.buttons.take_picture');
    await userEvent.click(button);
    await userEvent.click(getByLabelText('users.personal_key.close'));
    const upload = getByText('Upload');
    fireEvent.click(upload);

    expect(trackEvent.callCount).to.be.at.least(3);
    expect(trackEvent).to.have.been.calledWith('IdV: test image clicked', {
      source: 'placeholder',
      isDrop: false,
    });
    expect(trackEvent).to.have.been.calledWith('IdV: test image clicked', {
      source: 'button',
      isDrop: false,
    });
    expect(trackEvent).to.have.been.calledWith('IdV: test image clicked', {
      source: 'upload',
      isDrop: false,
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
      source: 'placeholder',
      isDrop: true,
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
      sinon.match({ attempt: 1 }),
    );

    uploadFile(input, validUpload);

    await expect(trackEvent).to.eventually.be.calledWith(
      'IdV: test image added',
      sinon.match({ attempt: 2 }),
    );
  });
});
