import React from 'react';
import { fireEvent, cleanup } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import AcuantCapture, {
  getDataURLFileSize,
} from '@18f/identity-document-capture/components/acuant-capture';
import { Provider as AcuantContextProvider } from '@18f/identity-document-capture/context/acuant';
import DeviceContext from '@18f/identity-document-capture/context/device';
import DataURLFile from '@18f/identity-document-capture/models/data-url-file';
import render from '../../../support/render';

describe('document-capture/components/acuant-capture', () => {
  afterEach(() => {
    // While RTL will perform this automatically, it must to occur prior to
    // resetting the global variables, since otherwise the component's effect
    // unsubscribe will attempt to reference globals that no longer exist.
    cleanup();
    delete window.AcuantJavascriptWebSdk;
    delete window.AcuantCamera;
    delete window.AcuantCameraUI;
  });

  describe('getDataURLFileSize', () => {
    it('returns file size in bytes', () => {
      const result = getDataURLFileSize(
        'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
      );

      expect(result).to.equal(41);
    });

    it('returns file size of bytes (base64)', () => {
      const result = getDataURLFileSize(
        'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciLz4=',
      );

      expect(result).to.equal(41);
    });
  });

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

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onFail }) => onFail(),
      };
      window.onAcuantSdkLoaded();

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

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();

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

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = { start: sinon.spy(), end: sinon.spy() };

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

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = { start: sinon.spy(), end: sinon.spy() };

      const button = getByLabelText('Image');
      fireEvent.click(button);

      expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
      expect(window.AcuantCameraUI.end.called).to.be.false();
    });

    it('calls onChange with the captured image on successful capture', () => {
      const onChange = sinon.spy();
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" onChange={onChange} />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = {
        start(onImageCaptureSuccess) {
          const capture = {
            glare: 70,
            sharpness: 70,
            image: {
              data: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
            },
          };
          onImageCaptureSuccess(capture);
        },
        end: sinon.spy(),
      };

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      expect(onChange.getCall(0).args).to.have.lengthOf(1);
      expect(onChange.getCall(0).args[0]).to.be.instanceOf(DataURLFile);
      expect(onChange.getCall(0).args[0].data).to.be.equal(
        'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
      );
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

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = {
        start: sinon.spy(),
        end: sinon.spy(),
      };

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
              value={
                new DataURLFile('data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E')
              }
            />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = { start: sinon.spy(), end: sinon.spy() };

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
              value={
                new DataURLFile('data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E')
              }
            />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: false };
      window.onAcuantSdkLoaded();

      const button = getByText('doc_auth.buttons.upload_picture');
      expect(button).to.be.ok();

      userEvent.click(button);
    });

    it('renders error message if capture succeeds but photo glare exceeds threshold', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = {
        start(onImageCaptureSuccess) {
          const capture = {
            glare: 38,
            sharpness: 70,
            image: {
              data: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
            },
          };
          onImageCaptureSuccess(capture);
        },
        end: sinon.spy(),
      };

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      const error = getByText('errors.doc_auth.photo_glare');

      expect(error).to.be.ok();
    });

    it('renders error message if capture succeeds but photo is too blurry', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = {
        start(onImageCaptureSuccess) {
          const capture = {
            glare: 70,
            sharpness: 20,
            image: {
              data: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
            },
          };
          onImageCaptureSuccess(capture);
        },
        end: sinon.spy(),
      };

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      const error = getByText('errors.doc_auth.photo_blurry');

      expect(error).to.be.ok();
    });

    it('shows at most one error message between AcuantCapture and FileInput', () => {
      const { getByLabelText, getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = {
        start(onImageCaptureSuccess) {
          const capture = {
            glare: 70,
            sharpness: 20,
            image: {
              data: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
            },
          };
          onImageCaptureSuccess(capture);
        },
        end: sinon.spy(),
      };

      const file = new window.File([''], 'upload.txt', { type: 'text/plain' });

      const input = getByLabelText('Image');
      userEvent.upload(input, file);

      expect(getByText('errors.doc_auth.selfie')).to.be.ok();

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      expect(getByText('errors.doc_auth.photo_blurry')).to.be.ok();
      expect(() => getByText('errors.doc_auth.selfie')).to.throw();
    });

    it('removes error message once image is corrected', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      let isBlurry = true;

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = {
        start(onImageCaptureSuccess) {
          const capture = {
            glare: 70,
            sharpness: isBlurry ? 20 : 70,
            image: {
              data: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
            },
          };
          onImageCaptureSuccess(capture);
        },
        end: sinon.spy(),
      };

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      isBlurry = false;

      fireEvent.click(button);

      expect(() => getByText('errors.doc_auth.photo_file_size')).to.throw();
    });

    it('renders error message if capture succeeds but photo is too small', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank">
            <AcuantCapture label="Image" minimumFileSize={500 * 1024} />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();
      window.AcuantCameraUI = {
        start(onImageCaptureSuccess) {
          const capture = {
            glare: 70,
            sharpness: 38,
            image: {
              data: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
            },
          };
          onImageCaptureSuccess(capture);
        },
        end: sinon.spy(),
      };

      const button = getByText('doc_auth.buttons.take_picture');
      fireEvent.click(button);

      const error = getByText('errors.doc_auth.photo_blurry');

      expect(error).to.be.ok();
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
  });

  it('renders with custom className', () => {
    const { container } = render(<AcuantCapture label="File" className="my-custom-class" />);

    expect(container.firstChild.classList.contains('my-custom-class')).to.be.true();
  });

  it('does not show hint if capture is supported', () => {
    const { getByText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
    };
    window.AcuantCamera = { isCameraSupported: true };
    window.onAcuantSdkLoaded();

    expect(() => getByText('doc_auth.tips.document_capture_hint')).to.throw();
  });

  it('shows hint if capture is not supported', () => {
    const { getByText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onFail }) => onFail(),
    };
    window.onAcuantSdkLoaded();

    const hint = getByText('doc_auth.tips.document_capture_hint');

    expect(hint).to.be.ok();
  });
});
