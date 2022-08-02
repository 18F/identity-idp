import { AcuantContextProvider, DeviceContext } from '@18f/identity-document-capture';
import AcuantCamera from '@18f/identity-document-capture/components/acuant-camera';
import AcuantCaptureCanvas from '@18f/identity-document-capture/components/acuant-capture-canvas';
import { render, useAcuant } from '../../../support/document-capture';

describe('document-capture/components/acuant-camera', () => {
  const { initialize } = useAcuant();

  it('waits for initialization', () => {
    render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <AcuantCamera>
            <AcuantCaptureCanvas />
          </AcuantCamera>
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
        BIG_DOCUMENT: 'doc_auth.info.capture_status_big_document',
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
          <AcuantCamera>
            <AcuantCaptureCanvas />
          </AcuantCamera>
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    initialize();
    unmount();

    expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
  });
});
