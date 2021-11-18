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

    it('calls the callback on changes, with the changed value', () => {
      const callback = sinon.spy();
      const object = {};
      defineObservableProperty(object, 'key', callback);
      object.key = 'value';

      expect(callback).to.have.been.calledOnceWithExactly('value');
    });
  });

  it('waits for initialization', () => {
    render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
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
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <AcuantCaptureCanvas />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    initialize();
    unmount();

    expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
  });

  it('renders a "take photo" button', () => {
    const { getByRole, container } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <AcuantCaptureCanvas />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    initialize();

    const button = getByRole('button', { name: 'doc_auth.buttons.take_picture' });

    expect(button.disabled).to.be.true();

    // This assumes that Acuant SDK will assign its own click handlers to respond to clicks on the
    // canvas, which happens in combination with assigning the callback property to the canvas.
    const canvas = container.querySelector('canvas');
    canvas.callback = () => {};

    expect(button.disabled).to.be.false();

    const onClick = sinon.spy();
    canvas.addEventListener('click', onClick);
    userEvent.click(button);
    userEvent.type(button, 'b{space}{enter}', { skipClick: true });
    expect(onClick).to.have.been.calledThrice();
  });
});
