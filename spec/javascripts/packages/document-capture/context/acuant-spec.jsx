import sinon from 'sinon';
import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import { DeviceContext, AnalyticsContext } from '@18f/identity-document-capture';
import AcuantContext, {
  dirname,
  Provider as AcuantContextProvider,
  DEFAULT_ACCEPTABLE_GLARE_SCORE,
  DEFAULT_ACCEPTABLE_SHARPNESS_SCORE,
} from '@18f/identity-document-capture/context/acuant';
import { render, useAcuant } from '../../../support/document-capture';

describe('document-capture/context/acuant', () => {
  const { initialize } = useAcuant();

  describe('dirname', () => {
    it('returns the containing directory with trailing slash', () => {
      const file = '/acuant/AcuantJavascriptWebSdk.min.js';
      const result = dirname(file);

      expect(result).to.equal('/acuant/');
    });
  });

  it('provides default context value', () => {
    const { result } = renderHook(() => useContext(AcuantContext));

    expect(result.current).to.have.keys([
      'isReady',
      'isAcuantLoaded',
      'isError',
      'isCameraSupported',
      'isActive',
      'setIsActive',
      'credentials',
      'endpoint',
      'glareThreshold',
      'sharpnessThreshold',
    ]);
    expect(result.current.isReady).to.be.false();
    expect(result.current.isAcuantLoaded).to.be.false();
    expect(result.current.isError).to.be.false();
    expect(result.current.isCameraSupported).to.be.null();
    expect(result.current.isActive).to.be.false();
    expect(result.current.setIsActive).to.be.a('function');
    expect(result.current.credentials).to.be.null();
    expect(result.current.endpoint).to.be.null();
    expect(result.current.glareThreshold).to.equal(DEFAULT_ACCEPTABLE_GLARE_SCORE);
    expect(result.current.sharpnessThreshold).to.equal(DEFAULT_ACCEPTABLE_SHARPNESS_SCORE);
  });

  it('allows configurable acceptable scores', () => {
    const { result } = renderHook(() => useContext(AcuantContext), {
      wrapper: ({ children }) => (
        <AcuantContextProvider glareThreshold={60} sharpnessThreshold={70}>
          {children}
        </AcuantContextProvider>
      ),
    });

    expect(result.current.glareThreshold).to.equal(60);
    expect(result.current.sharpnessThreshold).to.equal(70);
  });

  context('desktop', () => {
    it('does not append script element', () => {
      render(
        <DeviceContext.Provider value={{ isMobile: false }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank" />
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

      expect(result.current.isReady).to.be.true();
      expect(result.current.isAcuantLoaded).to.be.false();
      expect(result.current.isError).to.be.false();
      expect(result.current.isCameraSupported).to.be.false();
    });
  });

  context('mobile', () => {
    it('appends script element', () => {
      render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank" />
        </DeviceContext.Provider>,
      );

      const script = document.querySelector('script[src="about:blank"]');

      expect(script).to.be.ok();
    });

    it('provides context from provider credentials', () => {
      const { result } = renderHook(() => useContext(AcuantContext), {
        wrapper: ({ children }) => (
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider
              sdkSrc="about:blank"
              cameraSrc="about:blank"
              credentials="a"
              endpoint="b"
            >
              {children}
            </AcuantContextProvider>
          </DeviceContext.Provider>
        ),
      });

      expect(result.current.credentials).to.equal('a');
      expect(result.current.endpoint).to.equal('b');
    });

    context('successful initialization', () => {
      let result;
      let trackEvent;

      beforeEach(() => {
        trackEvent = sinon.spy();
        ({ result } = renderHook(() => useContext(AcuantContext), {
          wrapper: ({ children }) => (
            <AnalyticsContext.Provider value={{ trackEvent }}>
              <DeviceContext.Provider value={{ isMobile: true }}>
                <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                  {children}
                </AcuantContextProvider>
              </DeviceContext.Provider>
            </AnalyticsContext.Provider>
          ),
        }));
      });

      context('camera supported', () => {
        beforeEach(() => {
          initialize({ isCameraSupported: true });
        });

        it('provides ready context', () => {
          expect(result.current.isReady).to.be.true();
          expect(result.current.isAcuantLoaded).to.be.true();
          expect(result.current.isError).to.be.false();
          expect(result.current.isCameraSupported).to.be.true();
        });

        it('logs', () => {
          expect(trackEvent).to.have.been.calledWith('IdV: Acuant SDK loaded', {
            success: true,
            isCameraSupported: true,
          });
        });
      });

      context('camera not supported', () => {
        beforeEach(() => {
          initialize({ isCameraSupported: false });
        });

        it('provides ready context', () => {
          expect(result.current.isReady).to.be.true();
          expect(result.current.isAcuantLoaded).to.be.true();
          expect(result.current.isError).to.be.false();
          expect(result.current.isCameraSupported).to.be.false();
        });

        it('logs', () => {
          expect(trackEvent).to.have.been.calledWith('IdV: Acuant SDK loaded', {
            success: true,
            isCameraSupported: false,
          });
        });
      });
    });

    context('failed initialization', () => {
      let result;
      let trackEvent;

      beforeEach(() => {
        trackEvent = sinon.spy();
        ({ result } = renderHook(() => useContext(AcuantContext), {
          wrapper: ({ children }) => (
            <AnalyticsContext.Provider value={{ trackEvent }}>
              <DeviceContext.Provider value={{ isMobile: true }}>
                <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                  {children}
                </AcuantContextProvider>
              </DeviceContext.Provider>
            </AnalyticsContext.Provider>
          ),
        }));

        initialize({ isSuccess: false });
      });

      it('provides error context', () => {
        expect(result.current.isReady).to.be.false();
        expect(result.current.isAcuantLoaded).to.be.false();
        expect(result.current.isError).to.be.true();
        expect(result.current.isCameraSupported).to.be.null();
      });

      it('logs', () => {
        expect(trackEvent).to.have.been.calledWith('IdV: Acuant SDK loaded', {
          success: false,
          code: sinon.match.number,
          description: sinon.match.string,
        });
      });
    });

    it('has camera availability at time of ready', () => {
      const { result } = renderHook(() => useContext(AcuantContext), {
        wrapper: ({ children }) => (
          <DeviceContext.Provider value={{ isMobile: true }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              {children}
            </AcuantContextProvider>
          </DeviceContext.Provider>
        ),
      });

      initialize();

      expect(result.current.isCameraSupported).to.be.true();
    });

    it('cleans up after itself on unmount', () => {
      const { unmount } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank" />
        </DeviceContext.Provider>,
      );

      unmount();

      const script = document.querySelector('script[src="about:blank"]');

      expect(script).not.to.be.ok();
      expect(window.AcuantJavascriptWebSdk).to.be.undefined();
    });
  });
});
