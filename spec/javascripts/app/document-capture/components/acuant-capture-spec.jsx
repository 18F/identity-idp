import React from 'react';
import { fireEvent, cleanup } from '@testing-library/react';
import { waitForElementToBeRemoved } from '@testing-library/dom';
import sinon from 'sinon';
import render from '../../../support/render';
import AcuantCapture from '../../../../../app/javascript/app/document-capture/components/acuant-capture';
import { Provider as AcuantContextProvider } from '../../../../../app/javascript/app/document-capture/context/acuant';
import DeviceContext from '../../../../../app/javascript/app/document-capture/context/device';

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

  it('renders without capture button indicator if acuant script fails to load', async () => {
    const { getByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="/gone.js">
          <AcuantCapture label="Image" />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    await waitForElementToBeRemoved(getByText('doc_auth.buttons.take_picture'));
    expect(console).to.have.loggedError(/^Error: Could not load script:/);
  });

  it('renders without capture button if acuant fails to initialize', () => {
    const { getByText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onFail }) => onFail(),
    };
    window.onAcuantSdkLoaded();

    expect(() => getByText('doc_auth.buttons.take_picture')).to.throw();
  });

  it('renders a button when successfully loaded', () => {
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

    const button = getByText('doc_auth.buttons.take_picture');

    expect(button).to.be.ok();
  });

  it('renders a canvas when capturing', () => {
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
    window.AcuantCameraUI = { start: sinon.spy(), end: sinon.spy() };

    const button = getByText('doc_auth.buttons.take_picture');
    fireEvent.click(button);

    expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
    expect(window.AcuantCameraUI.end.called).to.be.false();
  });

  it('starts capturing when clicking input on supported device', () => {
    const { getByLabelText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" />
      </AcuantContextProvider>,
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
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" onChange={onChange} />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
    };
    window.AcuantCamera = { isCameraSupported: true };
    window.onAcuantSdkLoaded();
    window.AcuantCameraUI = {
      start(onImageCaptureSuccess) {
        const capture = {
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

    expect(onChange.getCall(0).args).to.deep.equal([
      'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
    ]);
    expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
  });

  it('renders the button when the capture failed', () => {
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
    window.AcuantCameraUI = {
      start(_onImageCaptureSuccess, onImageCaptureFailure) {
        onImageCaptureFailure(new Error());
      },
      end: sinon.spy(),
    };

    let button = getByText('doc_auth.buttons.take_picture');
    fireEvent.click(button);
    button = getByText('doc_auth.buttons.take_picture');

    expect(button).to.be.ok();
    expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
  });

  it('ends the capture when the component unmounts', () => {
    const { getByText, unmount } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture label="Image" />
      </AcuantContextProvider>,
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

  it('renders with custom className', () => {
    const { container } = render(<AcuantCapture label="File" className="my-custom-class" />);

    expect(container.firstChild.classList.contains('my-custom-class')).to.be.true();
  });
});
