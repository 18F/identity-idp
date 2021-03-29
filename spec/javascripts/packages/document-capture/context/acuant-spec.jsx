import sinon from 'sinon';
import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import { DeviceContext, AnalyticsContext } from '@18f/identity-document-capture';
import AcuantContext, {
  Provider as AcuantContextProvider,
} from '@18f/identity-document-capture/context/acuant';
import { render } from '../../../support/document-capture';

describe('document-capture/context/acuant', () => {
  afterEach(() => {
    delete window.AcuantJavascriptWebSdk;
    delete window.AcuantCamera;
  });

  it('provides default context value', () => {
    const { result } = renderHook(() => useContext(AcuantContext));

    expect(result.current).to.eql({
      isReady: false,
      isAcuantLoaded: false,
      isError: false,
      isCameraSupported: null,
      credentials: null,
      endpoint: null,
    });
  });

  context('desktop', () => {
    it('does not append script element', () => {
      render(
        <DeviceContext.Provider value={{ isMobile: false }}>
          <AcuantContextProvider sdkSrc="about:blank" />
        </DeviceContext.Provider>,
      );

      const script = document.querySelector('script[src="about:blank"]');

      expect(script).to.not.be.ok();
    });

    it('provides context as ready, unsupported', () => {
      const { result } = renderHook(() => useContext(AcuantContext), {
        wrapper: ({ children }) => (
          <DeviceContext.Provider value={{ isMobile: false }}>
            <AcuantContextProvider>{children}</AcuantContextProvider>
          </DeviceContext.Provider>
        ),
      });

      expect(result.current).to.eql({
        isReady: true,
        isAcuantLoaded: false,
        isError: false,
        isCameraSupported: false,
        credentials: null,
        endpoint: null,
      });
    });
  });

  context('mobile', () => {
    it('appends script element', () => {
      render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" />
        </DeviceContext.Provider>,
      );

      const script = document.querySelector('script[src="about:blank"]');

      expect(script).to.be.ok();
    });

    it('provides context from provider crendentials', () => {
      const { result } = renderHook(() => useContext(AcuantContext), {
        wrapper: ({ children }) => (
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" credentials="a" endpoint="b">
              {children}
            </AcuantContextProvider>
          </DeviceContext.Provider>
        ),
      });

      expect(result.current).to.eql({
        isReady: false,
        isAcuantLoaded: false,
        isError: false,
        isCameraSupported: null,
        credentials: 'a',
        endpoint: 'b',
      });
    });

    context('successful initialization', () => {
      let result;
      let addPageAction;

      beforeEach(() => {
        addPageAction = sinon.spy();
        ({ result } = renderHook(() => useContext(AcuantContext), {
          wrapper: ({ children }) => (
            <AnalyticsContext.Provider value={{ addPageAction }}>
              <DeviceContext.Provider value={{ isMobile: true }}>
                <AcuantContextProvider sdkSrc="about:blank">{children}</AcuantContextProvider>
              </DeviceContext.Provider>
            </AnalyticsContext.Provider>
          ),
        }));

        window.AcuantJavascriptWebSdk = {
          initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
        };
        window.AcuantCamera = { isCameraSupported: true };
        window.onAcuantSdkLoaded();
      });

      it('provides ready context', () => {
        expect(result.current).to.eql({
          isReady: true,
          isAcuantLoaded: true,
          isError: false,
          isCameraSupported: true,
          credentials: null,
          endpoint: null,
        });
      });

      it('logs', () => {
        expect(addPageAction).to.have.been.calledWith({
          label: 'IdV: Acuant SDK loaded',
          payload: {
            success: true,
          },
        });
      });
    });

    context('failed initialization', () => {
      let result;
      let addPageAction;

      beforeEach(() => {
        addPageAction = sinon.spy();
        ({ result } = renderHook(() => useContext(AcuantContext), {
          wrapper: ({ children }) => (
            <AnalyticsContext.Provider value={{ addPageAction }}>
              <DeviceContext.Provider value={{ isMobile: true }}>
                <AcuantContextProvider sdkSrc="about:blank">{children}</AcuantContextProvider>
              </DeviceContext.Provider>
            </AnalyticsContext.Provider>
          ),
        }));

        window.AcuantJavascriptWebSdk = {
          initialize: (_credentials, _endpoint, { onFail }) =>
            onFail(401, 'Server returned a 401 (missing credentials).'),
        };
        window.onAcuantSdkLoaded();
      });

      it('provides error context', () => {
        expect(result.current).to.eql({
          isReady: false,
          isAcuantLoaded: false,
          isError: true,
          isCameraSupported: null,
          credentials: null,
          endpoint: null,
        });
      });

      it('logs', () => {
        expect(addPageAction).to.have.been.calledWith({
          label: 'IdV: Acuant SDK loaded',
          payload: {
            success: false,
            code: sinon.match.number,
            description: sinon.match.string,
          },
        });
      });
    });

    it('has camera availability at time of ready', () => {
      const { result } = renderHook(() => useContext(AcuantContext), {
        wrapper: ({ children }) => (
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank">{children}</AcuantContextProvider>
          </DeviceContext.Provider>
        ),
      });

      window.AcuantJavascriptWebSdk = {
        initialize: (_credentials, _endpoint, { onSuccess }) => onSuccess(),
      };
      window.AcuantCamera = { isCameraSupported: true };
      window.onAcuantSdkLoaded();

      expect(result.current.isCameraSupported).to.be.true();
    });

    it('cleans up after itself on unmount', () => {
      const { unmount } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" />
        </DeviceContext.Provider>,
      );

      unmount();

      const script = document.querySelector('script[src="about:blank"]');

      expect(script).not.to.be.ok();
      expect(window.AcuantJavascriptWebSdk).to.be.undefined();
    });
  });
});
