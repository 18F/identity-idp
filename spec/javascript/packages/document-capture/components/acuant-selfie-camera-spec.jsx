import { AcuantContextProvider, DeviceContext } from '@18f/identity-document-capture';
import AcuantSelfieCamera from '@18f/identity-document-capture/components/acuant-selfie-camera';
import AcuantSelfieCaptureCanvas from '@18f/identity-document-capture/components/acuant-selfie-capture-canvas';
import { t } from '@18f/identity-i18n';
import { render, useAcuant } from '../../../support/document-capture';

describe('document-capture/components/acuant-selfie-camera', () => {
  const { initialize } = useAcuant();

  it('waits for initialization', () => {
    render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <AcuantSelfieCamera>
            <AcuantSelfieCaptureCanvas />
          </AcuantSelfieCamera>
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    // At this point, it's assumed `window.AcuantPassivelivenss.start` has not been called. This can't be
    // asserted, since the global is only assigned as part of `initialize` itself. But we can rely
    // on the fact that if it was called, an error would be thrown, and the test would fail.

    initialize();

    expect(window.AcuantPassiveLiveness.start.calledOnce).to.be.true();

    const callbacks = window.AcuantPassiveLiveness.start.getCall(0).args[0];
    const callbackNames = Object.keys(callbacks).sort;
    const expectedCallbackNames = [
      'onDetectorInitialized',
      'onDetection',
      'onOpened',
      'onClosed',
      'onError',
      'onPhotoTaken',
      'onPhotoRetake',
      'onCaptured',
    ].sort;
    expect(callbackNames).to.equal(expectedCallbackNames);

    expect(window.AcuantPassiveLiveness.start.getCall(0).args[1]).to.deep.equal({
      FACE_NOT_FOUND: t('doc_auth.info.selfie_capture_status.face_not_found'),
      TOO_MANY_FACES: t('doc_auth.info.selfie_capture_status.too_many_faces'),
      FACE_TOO_SMALL: t('doc_auth.info.selfie_capture_status.face_too_small'),
      FACE_CLOSE_TO_BORDER: t('doc_auth.info.selfie_capture_status.face_close_to_border'),
      CLOSE_TEXT: t('doc_auth.info.selfie_capture.action.close'),
      RETAKE_TEXT: t('doc_auth.info.selfie_capture.action.retake'),
      INTRO_TEXT: t('doc_auth.info.selfie_capture.intro'),
      SUBMIT_ALT: t('doc_auth.info.selfie_capture.action.submit'),
      CAPTURE_ALT: t('doc_auth.info.selfie_capture.action.capture'),
    });
  });

  it('ends on unmount', () => {
    const { unmount } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <AcuantSelfieCamera>
            <AcuantSelfieCaptureCanvas />
          </AcuantSelfieCamera>
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    initialize();
    unmount();

    expect(window.AcuantPassiveLiveness.end.calledOnce).to.be.true();
  });
});
