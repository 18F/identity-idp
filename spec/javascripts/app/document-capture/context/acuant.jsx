import React, { useContext } from 'react';
import { render } from '@testing-library/react';
import AcuantContext, {
  Provider as AcuantContextProvider,
} from '../../../../../app/javascript/app/document-capture/context/acuant';
import { useDOM } from '../../../support/dom';

describe('document-capture/context/acuant', () => {
  useDOM();

  afterEach(() => {
    delete window.AcuantJavascriptWebSdk;
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
    window.onAcuantSdkLoaded();

    expect(JSON.parse(container.textContent)).to.eql({
      isReady: true,
      isError: false,
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
