import React from 'react';
import { render, fireEvent, cleanup } from '@testing-library/react';
import sinon from 'sinon';
import AcuantCapture from '../../../../../app/javascript/app/document-capture/components/acuant-capture';
import { Provider as AcuantContextProvider } from '../../../../../app/javascript/app/document-capture/context/acuant';

describe('document-capture/components/acuant-capture', () => {
  afterEach(() => {
    // While RTL will perform this automatically, it must to occur prior to
    // resetting the global variables, since otherwise the component's effect
    // unsubscribe will attempt to reference globals that no longer exist.
    cleanup();
    delete window.AcuantJavascriptWebSdk;
    delete window.AcuantCameraUI;
  });

  it('renders a loading indicator while acuant is not ready', () => {
    const { container } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture />
      </AcuantContextProvider>,
    );

    expect(container.textContent).to.equal('Loading…');
  });

  it('renders an error indicator if acuant fails to load', () => {
    const { container } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onFail }) => onFail(),
    };
    window.onAcuantSdkLoaded();

    expect(container.textContent).to.equal('Error!');
  });

  it('renders a button when successfully loaded', () => {
    const { getByText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
    };
    window.onAcuantSdkLoaded();

    const button = getByText('doc_auth.buttons.take_picture');

    expect(button).to.be.ok();
  });

  it('renders a canvas when capturing', () => {
    const { getByText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
    };
    window.onAcuantSdkLoaded();
    window.AcuantCameraUI = { start: sinon.spy(), end: sinon.spy() };

    const button = getByText('doc_auth.buttons.take_picture');
    fireEvent.click(button);

    expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
    expect(window.AcuantCameraUI.end.called).to.be.false();
  });

  it('renders the captured image on successful capture', () => {
    const { getByText, getByAltText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
    };
    window.onAcuantSdkLoaded();
    window.AcuantCameraUI = {
      start(onImageCaptureSuccess) {
        const capture = {
          image: {
            data: 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E',
            width: 10,
            height: 20,
          },
        };
        onImageCaptureSuccess(capture);
      },
      end: sinon.spy(),
    };

    const button = getByText('doc_auth.buttons.take_picture');
    fireEvent.click(button);

    const image = getByAltText('Captured result');

    expect(image).to.be.ok();
    expect(image.src).to.equal('data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg"/%3E');
    expect(image.width).to.equal(10);
    expect(image.height).to.equal(20);
    expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
  });

  it('renders the button when the capture failed', () => {
    const { getByText } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCapture />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
    };
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
        <AcuantCapture />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
    };
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
});
