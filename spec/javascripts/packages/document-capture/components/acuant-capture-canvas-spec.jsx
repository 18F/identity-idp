import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { AcuantContextProvider, DeviceContext } from '@18f/identity-document-capture';
import AcuantCaptureCanvas, {
  defineObservableProperty,
} from '@18f/identity-document-capture/components/acuant-capture-canvas';
import { render, useAcuant } from '../../../support/document-capture';

describe('document-capture/components/acuant-capture-canvas', () => {
  const { initialize } = useAcuant();

  describe('defineObservableProperty', () => {
    it('behaves like an object', () => {
      const object = {};
      defineObservableProperty(object, 'key', () => {});
      object.key = 'value';

      expect(object.key).to.equal('value');
    });

    it('calls the callback on changes', () => {
      const callback = sinon.spy();
      const object = {};
      defineObservableProperty(object, 'key', callback);
      object.key = 'value';

      expect(callback).to.have.been.calledOnceWithExactly();
    });
  });

  it('waits for initialization', () => {
    render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank">
          <AcuantCaptureCanvas />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    // At this point, it's assumed `window.AcuantCameraUI.start` has not been called. This can't be
    // asserted, since the global is only assigned as part of `initialize` itself. But we can rely
    // on the fact that if it was called, an error would be thrown, and the test would fail.

    initialize();

    expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
    expect(window.AcuantCameraUI.start.getCall(0).args[2]).to.deep.equal({
      text: {
        CAPTURING: 'doc_auth.info.capture_status_capturing',
        GOOD_DOCUMENT: null,
        NONE: 'doc_auth.info.capture_status_none',
        SMALL_DOCUMENT: 'doc_auth.info.capture_status_small_document',
        TAP_TO_CAPTURE: 'doc_auth.info.capture_status_tap_to_capture',
      },
    });
  });

  it('ends on unmount', () => {
    const { unmount } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank">
          <AcuantCaptureCanvas />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    initialize();
    unmount();

    expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
  });

  it('renders a labelled button', () => {
    const { getByRole } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank">
          <AcuantCaptureCanvas />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    initialize();

    const button = getByRole('button', {
      name: 'doc_auth.accessible_labels.camera_video_capture_label',
    });
    userEvent.click(button);
    userEvent.type(button, 'b{space}{enter}', { skipClick: true });
    expect(button).to.be.ok();
    expect(window.AcuantCamera.triggerCapture).to.have.been.calledThrice();
  });

  it('defers to Acuant tap to capture', () => {
    const { getByRole } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank">
          <AcuantCaptureCanvas />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    initialize();

    // This assumes that Acuant SDK will assign its own click handlers to respond to clicks on the
    // canvas, which happens in combination with assigning the callback property to the canvas.
    const canvas = getByRole('button');
    canvas.callback = () => {};

    userEvent.click(canvas);

    // It's expected that the capture will be handled internally in Acuant SDK, not as a result of
    // an explicit call to the triggerCapture public API.
    expect(window.AcuantCamera.triggerCapture).not.to.have.been.called();
  });
});
