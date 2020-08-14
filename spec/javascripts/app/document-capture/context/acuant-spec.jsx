import React, { useContext } from 'react';
import render from '../../../support/render';
import AcuantContext, {
  Provider as AcuantContextProvider,
} from '../../../../../app/javascript/app/document-capture/context/acuant';

describe('document-capture/context/acuant', () => {
  afterEach(() => {
    delete window.AcuantJavascriptWebSdk;
    delete window.AcuantCamera;
  });

  function ContextReader() {
    const value = useContext(AcuantContext);
    return JSON.stringify(value);
  }

  it('provides default context value', () => {
    const { container } = render(<ContextReader />);

    expect(JSON.parse(container.textContent)).to.eql({
      isReady: false,
      isError: false,
      isCameraSupported: null,
      credentials: null,
      endpoint: null,
    });
  });

  it('appends script element', () => {
    render(
      <AcuantContextProvider sdkSrc="about:blank">
        <ContextReader />
      </AcuantContextProvider>,
    );

    const script = document.querySelector('script[src="about:blank"]');

    expect(script).to.be.ok();
  });

  it('provides context from provider crendentials', () => {
    const { container } = render(
      <AcuantContextProvider sdkSrc="about:blank" credentials="a" endpoint="b">
        <ContextReader />
      </AcuantContextProvider>,
    );

    expect(JSON.parse(container.textContent)).to.eql({
      isReady: false,
      isError: false,
      isCameraSupported: null,
      credentials: 'a',
      endpoint: 'b',
    });
  });

  it('provides ready context when successfully loaded', () => {
    const { container } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <ContextReader />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
    };
    window.AcuantCamera = { isCameraSupported: true };
    window.onAcuantSdkLoaded();

    expect(JSON.parse(container.textContent)).to.eql({
      isReady: true,
      isError: false,
      isCameraSupported: true,
      credentials: null,
      endpoint: null,
    });
  });

  it('provides error context when failed to loaded', () => {
    const { container } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <ContextReader />
      </AcuantContextProvider>,
    );

    window.AcuantJavascriptWebSdk = {
      initialize: (_credentials, _endpoint, { onFail }) => onFail(),
    };
    window.onAcuantSdkLoaded();

    expect(JSON.parse(container.textContent)).to.eql({
      isReady: false,
      isError: true,
      isCameraSupported: null,
      credentials: null,
      endpoint: null,
    });
  });

  it('cleans up after itself on unmount', () => {
    const { unmount } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <ContextReader />
      </AcuantContextProvider>,
    );

    unmount();

    const script = document.querySelector('script[src="about:blank"]');

    expect(script).not.to.be.ok();
    expect(window.AcuantJavascriptWebSdk).to.be.undefined();
  });
});
