import sinon from 'sinon';
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

  context('uncropped image capture', () => {
    const createMockImageData = (width, height) => {
      const data = new Uint8ClampedArray(width * height * 4);
      return { data, width, height, colorSpace: 'srgb' };
    };

    it('processes uncropped image data when onCaptured is called', () => {
      const onImageCaptureSuccess = sinon.stub();
      const onImageCaptureFailure = sinon.stub();
      const onCropStart = sinon.stub();

      render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCamera
              onImageCaptureSuccess={onImageCaptureSuccess}
              onImageCaptureFailure={onImageCaptureFailure}
              onCropStart={onCropStart}
            >
              <AcuantCaptureCanvas />
            </AcuantCamera>
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const acuantCallbacks = window.AcuantCameraUI.start.getCall(0).args[0];
      const mockImageData = createMockImageData(100, 100);
      const mockCaptureResponse = {
        data: mockImageData,
        width: 100,
        height: 100,
      };

      const mockCanvas = {
        width: 0,
        height: 0,
        getContext: sinon.stub().returns({
          putImageData: sinon.stub(),
        }),
        toDataURL: sinon.stub().returns('data:image/jpg;base64,mockBase64Data'),
      };
      const createElementStub = sinon.stub(document, 'createElement').returns(mockCanvas);

      acuantCallbacks.onCaptured(mockCaptureResponse);

      expect(onCropStart.called).to.be.true();
      expect(createElementStub).to.have.been.calledWith('canvas');
      expect(mockCanvas.getContext).to.have.been.calledWith('2d');
      expect(mockCanvas.width).to.equal(100);
      expect(mockCanvas.height).to.equal(100);

      createElementStub.restore();
    });

    it('passes uncropped data to onImageCaptureSuccess when onCropped is called', () => {
      const onImageCaptureSuccess = sinon.stub();
      const onImageCaptureFailure = sinon.stub();
      const onCropStart = sinon.stub();

      render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCamera
              onImageCaptureSuccess={onImageCaptureSuccess}
              onImageCaptureFailure={onImageCaptureFailure}
              onCropStart={onCropStart}
            >
              <AcuantCaptureCanvas />
            </AcuantCamera>
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const acuantCallbacks = window.AcuantCameraUI.start.getCall(0).args[0];
      const mockImageData = createMockImageData(100, 100);
      const mockCaptureResponse = {
        data: mockImageData,
        width: 100,
        height: 100,
      };

      const mockCanvas = {
        width: 0,
        height: 0,
        getContext: sinon.stub().returns({
          putImageData: sinon.stub(),
        }),
        toDataURL: sinon.stub().returns('data:image/jpg;base64,uncroppedData'),
      };
      const createElementStub = sinon.stub(document, 'createElement').returns(mockCanvas);

      acuantCallbacks.onCaptured(mockCaptureResponse);

      const mockCroppedResponse = {
        image: {
          data: 'data:image/jpg;base64,croppedData',
          width: 100,
          height: 100,
        },
        cardType: 1,
        glare: 100,
        sharpness: 100,
        moire: 100,
        moireraw: 100,
        dpi: 300,
      };

      acuantCallbacks.onCropped(mockCroppedResponse);

      expect(onImageCaptureSuccess).to.have.been.calledWith(
        mockCroppedResponse,
        'data:image/jpg;base64,uncroppedData',
      );

      createElementStub.restore();
    });

    it('handles onCropped failure when response is null', () => {
      const onImageCaptureSuccess = sinon.stub();
      const onImageCaptureFailure = sinon.stub();
      const onCropStart = sinon.stub();

      render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCamera
              onImageCaptureSuccess={onImageCaptureSuccess}
              onImageCaptureFailure={onImageCaptureFailure}
              onCropStart={onCropStart}
            >
              <AcuantCaptureCanvas />
            </AcuantCamera>
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const acuantCallbacks = window.AcuantCameraUI.start.getCall(0).args[0];
      acuantCallbacks.onCropped(null);

      expect(onImageCaptureFailure).to.have.been.called();
      expect(onImageCaptureSuccess).to.not.have.been.called();
    });

    it('clears uncropped data after onCropped is called', () => {
      const onImageCaptureSuccess = sinon.stub();
      const onImageCaptureFailure = sinon.stub();
      const onCropStart = sinon.stub();

      render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCamera
              onImageCaptureSuccess={onImageCaptureSuccess}
              onImageCaptureFailure={onImageCaptureFailure}
              onCropStart={onCropStart}
            >
              <AcuantCaptureCanvas />
            </AcuantCamera>
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const acuantCallbacks = window.AcuantCameraUI.start.getCall(0).args[0];
      const mockImageData = createMockImageData(100, 100);
      const mockCaptureResponse = {
        data: mockImageData,
        width: 100,
        height: 100,
      };

      const mockCanvas = {
        width: 0,
        height: 0,
        getContext: sinon.stub().returns({
          putImageData: sinon.stub(),
        }),
        toDataURL: sinon.stub().returns('data:image/jpg;base64,uncroppedData'),
      };
      const createElementStub = sinon.stub(document, 'createElement').returns(mockCanvas);

      acuantCallbacks.onCaptured(mockCaptureResponse);

      const mockCroppedResponse = {
        image: {
          data: 'data:image/jpg;base64,croppedData',
          width: 100,
          height: 100,
        },
        cardType: 1,
        glare: 100,
        sharpness: 100,
        moire: 100,
        moireraw: 100,
        dpi: 300,
      };

      acuantCallbacks.onCropped(mockCroppedResponse);
      acuantCallbacks.onCropped(mockCroppedResponse);

      expect(onImageCaptureSuccess.secondCall).to.have.been.calledWith(
        mockCroppedResponse,
        undefined,
      );

      createElementStub.restore();
    });

    it('handles error when processing uncropped image', () => {
      const onImageCaptureSuccess = sinon.stub();
      const onImageCaptureFailure = sinon.stub();
      const onCropStart = sinon.stub();

      render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCamera
              onImageCaptureSuccess={onImageCaptureSuccess}
              onImageCaptureFailure={onImageCaptureFailure}
              onCropStart={onCropStart}
            >
              <AcuantCaptureCanvas />
            </AcuantCamera>
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const acuantCallbacks = window.AcuantCameraUI.start.getCall(0).args[0];
      const mockImageData = createMockImageData(100, 100);
      const mockCaptureResponse = {
        data: mockImageData,
        width: 100,
        height: 100,
      };

      const mockCanvas = {
        getContext: sinon.stub().returns(null),
      };
      const createElementStub = sinon.stub(document, 'createElement').returns(mockCanvas);

      acuantCallbacks.onCaptured(mockCaptureResponse);

      expect(onCropStart).to.have.been.called();

      createElementStub.restore();
    });

    it('does not process uncropped data if response.data is missing', () => {
      const onImageCaptureSuccess = sinon.stub();
      const onImageCaptureFailure = sinon.stub();
      const onCropStart = sinon.stub();

      render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <AcuantCamera
              onImageCaptureSuccess={onImageCaptureSuccess}
              onImageCaptureFailure={onImageCaptureFailure}
              onCropStart={onCropStart}
            >
              <AcuantCaptureCanvas />
            </AcuantCamera>
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      initialize();

      const acuantCallbacks = window.AcuantCameraUI.start.getCall(0).args[0];
      const createElementStub = sinon.stub(document, 'createElement');

      acuantCallbacks.onCaptured({ width: 100, height: 100 });

      expect(onCropStart).to.have.been.called();
      expect(createElementStub).to.not.have.been.called();

      createElementStub.restore();
    });
  });
});
