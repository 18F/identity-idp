import sinon from 'sinon';
import { fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { waitFor, waitForElementToBeRemoved } from '@testing-library/dom';
import AcuantCapture from '@18f/identity-document-capture/components/acuant-capture';
import { AcuantContextProvider, AnalyticsContext } from '@18f/identity-document-capture';
import DeviceContext from '@18f/identity-document-capture/context/device';
import I18nContext from '@18f/identity-document-capture/context/i18n';
import { render, useAcuant } from '../../../support/document-capture';

const ACUANT_CAPTURE_SUCCESS_RESULT = {
  image: {
    data: 'data:image/png,',
    width: 1748,
    height: 1104,
  },
  cardType: 1,
  dpi: 519,
  glare: 100,
  sharpness: 100,
};

const ACUANT_CAPTURE_GLARE_RESULT = { ...ACUANT_CAPTURE_SUCCESS_RESULT, glare: 38 };
const ACUANT_CAPTURE_BLURRY_RESULT = { ...ACUANT_CAPTURE_SUCCESS_RESULT, sharpness: 38 };

describe('document-capture/components/acuant-capture', () => {
  const { initialize } = useAcuant();

  context('mobile', () => {
    it('renders with assumed capture button support while acuant is not ready and on mobile', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      expect(getByText('doc_auth.buttons.take_picture')).to.be.ok();
    });

    it('cancels capture if assumed support is not actually supported once ready', () => {
      const { container, getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      userEvent.click(getByText('doc_auth.buttons.take_picture'));

      initialize({ isCameraSupported: false });

      expect(container.querySelector('.full-screen')).to.be.null();
    });

    it('renders with upload button as mobile-primary (secondary) button if acuant script fails to load', async () => {
      const { findByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="/gone.js">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      const button = await findByText('doc_auth.buttons.upload_picture');
      expect(button.classList.contains('btn-secondary')).to.be.true();
      expect(console).to.have.loggedError(/^Error: Could not load script:/);
      userEvent.click(button);
    });

    it('renders without capture button if acuant fails to initialize', async () => {
      const { findByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize({ isSuccess: false });

      const button = await findByText('doc_auth.buttons.upload_picture');
      expect(button.classList.contains('btn-secondary')).to.be.true();
    });

    it('renders a button when successfully loaded', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
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
          <AcuantContextProvider sdkSrc="about:blank">
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

    it('starts capturing when clicking input on supported device', () => {
      const { getByLabelText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
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
      const { container, getByLabelText, findByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize({
        start: sinon.stub().callsArgWithAsync(1, new Error()),
      });

      const button = getByLabelText('Image');
      fireEvent.click(button);

      await findByText('errors.doc_auth.capture_failure');
      expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
      expect(container.querySelector('.full-screen')).to.be.null();
    });

    it('calls onChange with the captured image on successful capture', async () => {
      const onChange = sinon.mock();
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
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
      await new Promise((resolve) => onChange.callsFake(resolve));

      expect(onChange.getCall(0).args).to.have.lengthOf(1);
      expect(onChange.getCall(0).args[0]).to.equal('data:image/png,');
      expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
    });

    it('ends the capture when the component unmounts', () => {
      const { getByText, unmount } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
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

    it('renders retry button when value and capture supported', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture
              label="Image"
              value={new window.File([], 'image.svg', { type: 'image/svg+xml' })}
            />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const button = getByText('doc_auth.buttons.take_picture_retry');
      expect(button).to.be.ok();

      userEvent.click(button);
      expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
    });

    it('renders upload button when value and capture not supported', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture
              label="Image"
              value={new window.File([], 'image.svg', { type: 'image/svg+xml' })}
            />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize({ isCameraSupported: false });

      const button = getByText('doc_auth.buttons.upload_picture');
      expect(button).to.be.ok();

      userEvent.click(button);
    });

    it('renders error message if capture succeeds but photo glare exceeds threshold', async () => {
      const addPageAction = sinon.spy();
      const { getByText, findByText } = render(
        <AnalyticsContext.Provider value={{ addPageAction }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank">
              <AcuantCapture label="Image" name="image" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          await Promise.resolve();
          callbacks.onCropped(ACUANT_CAPTURE_GLARE_RESULT);
        }),
      });

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      const error = await findByText('errors.doc_auth.photo_glare');
      expect(addPageAction).to.have.been.calledWith({
        key: 'documentCapture.acuantWebSDKResult',
        label: 'IdV: Acuant web SDK photo analyzed',
        payload: {
          documentType: 'id',
          dpi: 519,
          fieldName: 'image',
          glare: 38,
          height: 1104,
          isAssessedAsBlurry: false,
          isAssessedAsGlare: true,
          result: 'glare',
          sharpness: 100,
          width: 1748,
        },
      });

      expect(error).to.be.ok();
    });

    it('renders error message if capture succeeds but photo is too blurry', async () => {
      const addPageAction = sinon.spy();
      const { getByText, findByText } = render(
        <AnalyticsContext.Provider value={{ addPageAction }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank">
              <AcuantCapture label="Image" name="image" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </AnalyticsContext.Provider>,
      );

      initialize({
        start: sinon.stub().callsFake(async (callbacks) => {
          await Promise.resolve();
          callbacks.onCaptured();
          await Promise.resolve();
          callbacks.onCropped(ACUANT_CAPTURE_BLURRY_RESULT);
        }),
      });

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      const error = await findByText('errors.doc_auth.photo_blurry');
      expect(addPageAction).to.have.been.calledWith({
        key: 'documentCapture.acuantWebSDKResult',
        label: 'IdV: Acuant web SDK photo analyzed',
        payload: {
          documentType: 'id',
          dpi: 519,
          fieldName: 'image',
          glare: 100,
          height: 1104,
          isAssessedAsBlurry: true,
          isAssessedAsGlare: false,
          result: 'blurry',
          sharpness: 38,
          width: 1748,
        },
      });

      expect(error).to.be.ok();
    });

    it('shows at most one error message between AcuantCapture and FileInput', async () => {
      const { getByLabelText, getByText, findByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
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
          callbacks.onCropped(ACUANT_CAPTURE_BLURRY_RESULT);
        }),
      });

      const file = new window.File([''], 'upload.txt', { type: 'text/plain' });

      const input = getByLabelText('Image');
      userEvent.upload(input, file);

      expect(await findByText('errors.doc_auth.invalid_file_input_type')).to.be.ok();

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      expect(getByText('errors.doc_auth.photo_blurry')).to.be.ok();
      expect(() => getByText('errors.doc_auth.invalid_file_input_type')).to.throw();
    });

    it('removes error message once image is corrected', async () => {
      const addPageAction = sinon.spy();
      const { getByText, findByText } = render(
        <AnalyticsContext.Provider value={{ addPageAction }}>
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank">
              <AcuantCapture label="Image" name="image" />
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
            callbacks.onCropped(ACUANT_CAPTURE_BLURRY_RESULT);
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

      const error = await findByText('errors.doc_auth.photo_blurry');

      fireEvent.click(button);
      await waitForElementToBeRemoved(error);
      expect(addPageAction).to.have.been.calledWith({
        key: 'documentCapture.acuantWebSDKResult',
        label: 'IdV: Acuant web SDK photo analyzed',
        payload: {
          documentType: 'id',
          dpi: 519,
          fieldName: 'image',
          glare: 100,
          height: 1104,
          isAssessedAsBlurry: true,
          isAssessedAsGlare: false,
          result: 'blurry',
          sharpness: 38,
          width: 1748,
        },
      });
    });

    it('triggers forced upload', () => {
      const { getByText } = render(
        <I18nContext.Provider
          value={{ 'doc_auth.buttons.take_or_upload_picture': '<lg-upload>Upload</lg-upload>' }}
        >
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank">
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

    it('triggers forced upload with `capture` value', () => {
      const { getByText, getByLabelText } = render(
        <I18nContext.Provider
          value={{ 'doc_auth.buttons.take_or_upload_picture': '<lg-upload>Upload</lg-upload>' }}
        >
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank">
              <AcuantCapture label="Image" capture="user" />
            </AcuantContextProvider>
          </DeviceContext.Provider>
        </I18nContext.Provider>,
      );

      initialize();

      const button = getByText('Upload');
      const input = getByLabelText('Image');
      const defaultPrevented = !fireEvent.click(button);

      expect(defaultPrevented).to.be.false();
      expect(window.AcuantCameraUI.start.called).to.be.false();
      expect(window.AcuantPassiveLiveness.startSelfieCapture.called).to.be.false();
      expect(input.getAttribute('capture')).to.equal('user');
    });

    it('optionally disallows upload', () => {
      const { getByText, getByLabelText } = render(
        <I18nContext.Provider
          value={{ 'doc_auth.buttons.take_or_upload_picture': '<lg-upload>Upload</lg-upload>' }}
        >
          <AcuantContextProvider sdkSrc="about:blank">
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantCapture label="Image" allowUpload={false} />
            </DeviceContext.Provider>
          </AcuantContextProvider>
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

    it('still captures selfie value when upload disallowed', () => {
      const { getByLabelText } = render(
        <AcuantContextProvider sdkSrc="about:blank">
          <AcuantCapture label="Image" capture="user" allowUpload={false} />
        </AcuantContextProvider>,
      );

      initialize();

      const button = getByLabelText('Image');
      const defaultPrevented = !fireEvent.click(button);

      expect(defaultPrevented).to.be.true();
      expect(window.AcuantCameraUI.start.called).to.be.false();
      expect(window.AcuantPassiveLiveness.startSelfieCapture.called).to.be.true();
    });
  });

  context('desktop', () => {
    it('renders without capture button while acuant is not ready and on desktop', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: false }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      expect(() => getByText('doc_auth.buttons.take_picture')).to.throw();
    });

    it('optionally disallows upload', () => {
      const { getByText } = render(
        <AcuantContextProvider sdkSrc="about:blank">
          <DeviceContext.Provider value={{ isMobile: false }}>
            <AcuantCapture label="Image" allowUpload={false} />
          </DeviceContext.Provider>
        </AcuantContextProvider>,
      );

      expect(() => getByText('doc_auth.tips.document_capture_hint')).to.throw();

      initialize();
    });
  });

  it('renders with custom className', () => {
    const { container } = render(<AcuantCapture label="File" className="my-custom-class" />);

    expect(container.firstChild.classList.contains('my-custom-class')).to.be.true();
  });

  it('clears a selected value', () => {
    const onChange = sinon.spy();
    const { getByLabelText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture
          label="Image"
          value={new window.File([], 'image.svg', { type: 'image/svg+xml' })}
          onChange={onChange}
        />
      </AcuantContextProvider>,
    );

    const input = getByLabelText('Image');
    fireEvent.change(input, { target: { files: [] } });

    expect(onChange.getCall(0).args).to.have.lengthOf(1);
    expect(onChange.getCall(0).args).to.deep.equal([null]);
  });

  it('does not show hint if capture is supported', () => {
    const { getByText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" />
      </AcuantContextProvider>,
    );

    initialize();

    expect(() => getByText('doc_auth.tips.document_capture_hint')).to.throw();
  });

  it('shows hint if capture is not supported', () => {
    const { getByText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" />
      </AcuantContextProvider>,
    );

    initialize({ isSuccess: false });

    const hint = getByText('doc_auth.tips.document_capture_hint');

    expect(hint).to.be.ok();
  });

  it('captures selfie', async () => {
    const onChange = sinon.stub();
    const { getByLabelText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" capture="user" onChange={onChange} />
      </AcuantContextProvider>,
    );

    initialize({
      startSelfieCapture: sinon.stub().callsArgWithAsync(0, ''),
    });

    const button = getByLabelText('Image');
    const defaultPrevented = !fireEvent.click(button);

    expect(defaultPrevented).to.be.true();
    expect(window.AcuantCameraUI.start.called).to.be.false();
    expect(window.AcuantPassiveLiveness.startSelfieCapture.called).to.be.true();
    await waitFor(() => expect(onChange.calledOnce).to.be.true());
  });

  it('restricts accepted file types', () => {
    const { getByLabelText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" />
      </AcuantContextProvider>,
      { isMockClient: false },
    );

    const input = getByLabelText('Image');

    expect(input.getAttribute('accept')).to.equal('image/jpeg,image/png,image/bmp,image/tiff');
  });
});
