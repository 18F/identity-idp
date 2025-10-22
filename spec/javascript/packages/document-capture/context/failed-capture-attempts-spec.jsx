import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import userEvent from '@testing-library/user-event';
import {
  DeviceContext,
  AnalyticsContext,
  SelfieCaptureContext,
} from '@18f/identity-document-capture';
import { Provider as AcuantContextProvider } from '@18f/identity-document-capture/context/acuant';
import AcuantCapture from '@18f/identity-document-capture/components/acuant-capture';
import FailedCaptureAttemptsContext, {
  Provider,
} from '@18f/identity-document-capture/context/failed-capture-attempts';
import sinon from 'sinon';
import { render } from '../../../support/document-capture';

describe('document-capture/context/failed-capture-attempts', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext));

    expect(result.current).to.have.keys([
      'failedCaptureAttempts',
      'failedSubmissionAttempts',
      'forceNativeCamera',
      'onFailedCaptureAttempt',
      'onFailedSubmissionAttempt',
      'onResetFailedCaptureAttempts',
      'maxCaptureAttemptsBeforeNativeCamera',
      'onFailedCameraPermissionAttempt',
      'failedCameraPermissionAttempts',
      'maxSubmissionAttemptsBeforeNativeCamera',
      'lastAttemptMetadata',
      'failedSubmissionImageFingerprints',
      'failedQualityCheckAttempts',
      'onFailedQualityCheckAttempt',
      'onResetFailedQualityCheckAttempts',
      'shouldTriggerManualCapture',
      'maxAttemptsBeforeManualCapture',
      'manualCaptureAfterFailuresEnabled',
    ]);
    expect(result.current.failedCaptureAttempts).to.equal(0);
    expect(result.current.failedSubmissionAttempts).to.equal(0);
    expect(result.current.onFailedSubmissionAttempt).to.be.a('function');
    expect(result.current.onFailedCaptureAttempt).to.be.a('function');
    expect(result.current.onResetFailedCaptureAttempts).to.be.a('function');
    expect(result.current.maxCaptureAttemptsBeforeNativeCamera).to.be.a('number');
    expect(result.current.lastAttemptMetadata).to.be.an('object');
    expect(result.current.failedSubmissionImageFingerprints).to.be.an('object');
    expect(result.current.failedQualityCheckAttempts).to.be.an('object');
    expect(result.current.onFailedQualityCheckAttempt).to.be.a('function');
    expect(result.current.onResetFailedQualityCheckAttempts).to.be.a('function');
    expect(result.current.shouldTriggerManualCapture).to.be.a('function');
    expect(result.current.maxAttemptsBeforeManualCapture).to.be.a('number');
    expect(result.current.manualCaptureAfterFailuresEnabled).to.be.a('boolean');
  });

  describe('Provider', () => {
    it('sets increments on onFailedCaptureAttempt', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
        wrapper: ({ children }) => (
          <Provider maxCaptureAttemptsBeforeNativeCamera={2}>{children}</Provider>
        ),
      });

      result.current.onFailedCaptureAttempt({ isAssessedAsGlare: true, isAssessedAsBlurry: false });

      expect(result.current.failedCaptureAttempts).to.equal(1);
    });

    it('sets metadata from onFailedCaptureAttempt', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
        wrapper: ({ children }) => <Provider>{children}</Provider>,
      });

      const metadata = { isAssessedAsGlare: true, isAssessedAsBlurry: false };

      result.current.onFailedCaptureAttempt(metadata);

      expect(result.current.lastAttemptMetadata).to.deep.equal(metadata);
    });
  });
});

describe('FailedCaptureAttemptsContext testing of forceNativeCamera logic', () => {
  it('Updating to a number of failed captures less than maxCaptureAttemptsBeforeNativeCamera will keep forceNativeCamera as false', () => {
    const { result, rerender } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
      wrapper: ({ children }) => (
        <Provider maxCaptureAttemptsBeforeNativeCamera={2}>{children}</Provider>
      ),
    });
    result.current.onFailedCaptureAttempt({
      isAssessedAsGlare: true,
      isAssessedAsBlurry: false,
    });
    rerender(true);
    expect(result.current.failedCaptureAttempts).to.equal(1);
    expect(result.current.forceNativeCamera).to.equal(false);
  });

  it('Updating to a number of failed submissions less than maxSubmissionAttemptsBeforeNativeCamera will keep forceNativeCamera as false', () => {
    const { result, rerender } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
      wrapper: ({ children }) => (
        <Provider maxSubmissionAttemptsBeforeNativeCamera={2}>{children}</Provider>
      ),
    });
    result.current.onFailedSubmissionAttempt({ front: ['abcdefg'], back: [] });
    rerender(true);
    expect(result.current.failedSubmissionAttempts).to.equal(1);
    expect(result.current.forceNativeCamera).to.equal(false);
    expect(result.current.failedSubmissionImageFingerprints).to.eql({
      front: ['abcdefg'],
      back: [],
    });
  });

  it('Updating failed captures to a number gte the maxCaptureAttemptsBeforeNativeCamera will set forceNativeCamera to true', () => {
    const { result, rerender } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
      wrapper: ({ children }) => (
        <Provider maxCaptureAttemptsBeforeNativeCamera={2}>{children}</Provider>
      ),
    });
    result.current.onFailedCaptureAttempt({
      isAssessedAsGlare: true,
      isAssessedAsBlurry: false,
    });
    rerender(true);
    expect(result.current.forceNativeCamera).to.equal(false);
    result.current.onFailedCaptureAttempt({
      isAssessedAsGlare: true,
      isAssessedAsBlurry: false,
    });
    rerender(true);
    expect(result.current.forceNativeCamera).to.equal(true);
    result.current.onFailedCaptureAttempt({
      isAssessedAsGlare: true,
      isAssessedAsBlurry: false,
    });
    rerender({});
    expect(result.current.failedCaptureAttempts).to.equal(3);
    expect(result.current.forceNativeCamera).to.equal(true);
  });

  it('Updating failed submissions to a number gte the maxSubmissionAttemptsBeforeNativeCamera will set forceNativeCamera to true', () => {
    const { result, rerender } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
      wrapper: ({ children }) => (
        <Provider maxSubmissionAttemptsBeforeNativeCamera={2}>{children}</Provider>
      ),
    });
    result.current.onFailedSubmissionAttempt();
    rerender(true);
    expect(result.current.forceNativeCamera).to.equal(false);
    result.current.onFailedSubmissionAttempt();
    rerender(true);
    expect(result.current.forceNativeCamera).to.equal(true);
    result.current.onFailedSubmissionAttempt();
    rerender({});
    expect(result.current.failedSubmissionAttempts).to.equal(3);
    expect(result.current.forceNativeCamera).to.equal(true);
  });

  it('Combination of failedCapture and failedSubmission gte max does NOT force native camera', () => {
    const { result, rerender } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
      wrapper: ({ children }) => (
        <Provider
          maxSubmissionAttemptsBeforeNativeCamera={3}
          maxCaptureAttemptsBeforeNativeCamera={3}
        >
          {children}
        </Provider>
      ),
    });
    result.current.onFailedSubmissionAttempt();
    result.current.onFailedSubmissionAttempt();
    result.current.onFailedCaptureAttempt({
      isAssessedAsGlare: true,
      isAssessedAsBlurry: false,
    });
    rerender(true);
    expect(result.current.failedSubmissionAttempts).to.equal(2);
    expect(result.current.failedCaptureAttempts).to.equal(1);
    expect(result.current.forceNativeCamera).to.equal(false);
  });

  describe('when selfie is enabled', () => {
    it('forceNativeCamera is always false, no matter how many times any attempt fails', () => {
      const trackEvent = sinon.spy();
      const { result, rerender } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
        wrapper: ({ children }) => (
          <SelfieCaptureContext.Provider value={{ isSelfieCaptureEnabled: true }}>
            <Provider
              maxCaptureAttemptsBeforeNativeCamera={2}
              maxSubmissionAttemptsBeforeNativeCamera={2}
            >
              {children}
            </Provider>
          </SelfieCaptureContext.Provider>
        ),
      });

      result.current.onFailedCaptureAttempt({
        isAssessedAsGlare: true,
        isAssessedAsBlurry: false,
      });
      rerender(true);
      expect(result.current.forceNativeCamera).to.equal(false);
      result.current.onFailedCaptureAttempt({
        isAssessedAsGlare: false,
        isAssessedAsBlurry: true,
      });
      rerender(true);
      expect(result.current.forceNativeCamera).to.equal(false);
      result.current.onFailedCaptureAttempt({
        isAssessedAsGlare: false,
        isAssessedAsBlurry: true,
      });
      rerender({});
      expect(result.current.failedCaptureAttempts).to.equal(3);
      expect(result.current.forceNativeCamera).to.equal(false);

      result.current.onFailedSubmissionAttempt();
      rerender(true);
      expect(result.current.forceNativeCamera).to.equal(false);
      result.current.onFailedSubmissionAttempt();
      rerender(true);
      expect(result.current.forceNativeCamera).to.equal(false);
      result.current.onFailedSubmissionAttempt();
      rerender({});
      expect(result.current.failedSubmissionAttempts).to.equal(3);
      expect(result.current.forceNativeCamera).to.equal(false);

      expect(trackEvent).to.not.have.been.calledWith(
        'IdV: Native camera forced after failed attempts',
      );
    });
  });
});

describe('maxCaptureAttemptsBeforeNativeCamera logging tests', () => {
  context('failed acuant camera attempts', function () {
    /**
     * NOTE: We have to force maxAttemptsBeforeLogin to be 0 here
     * in order to test this interactively. This is because the react
     * testing library does not provide consistent ways to test using both
     * a component's elements (for triggering clicks) and a component's
     * subscribed context changes. You can use either render or renderHook,
     * but not both.
     */
    it('calls analytics with native camera message when failed attempts is greater than or equal to 0', async function () {
      const trackEvent = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture name="example" />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                <Provider maxCaptureAttemptsBeforeNativeCamera={0}>
                  {acuantCaptureComponent}
                  {children}
                </Provider>
              </AcuantContextProvider>
            </DeviceContext.Provider>
          </AnalyticsContext.Provider>
        );
      }
      const result = render(<TestComponent />);
      const user = userEvent.setup();
      const fileInput = result.container.querySelector('input[type="file"]');
      expect(fileInput).to.exist();
      await user.click(fileInput);
      expect(trackEvent).to.have.been.called();
      expect(trackEvent).to.have.been.calledWith(
        'IdV: Native camera forced after failed attempts',
        { field: 'example', failed_capture_attempts: 0, failed_submission_attempts: 0 },
      );
    });

    it('Does not call analytics with native camera message when failed attempts less than 2', async function () {
      const trackEvent = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <DeviceContext.Provider value={{ isMobile: true }}>
              <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                <Provider maxCaptureAttemptsBeforeNativeCamera={2}>
                  {acuantCaptureComponent}
                  {children}
                </Provider>
              </AcuantContextProvider>
            </DeviceContext.Provider>
          </AnalyticsContext.Provider>
        );
      }
      const result = render(<TestComponent />);
      const user = userEvent.setup();
      const fileInput = result.container.querySelector('input[type="file"]');
      expect(fileInput).to.exist();
      await user.click(fileInput);
      expect(trackEvent).to.not.have.been.calledWith(
        'IdV: Native camera forced after failed attempts',
      );
    });

    it('Does not call forceNativeCamera analytics if the target environment is desktop and other criteria are met', async function () {
      const trackEvent = sinon.spy();
      const acuantCaptureComponent = <AcuantCapture />;
      function TestComponent({ children }) {
        return (
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <DeviceContext.Provider value={{ isMobile: false }}>
              <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
                <Provider
                  maxCaptureAttemptsBeforeNativeCamera={0}
                  maxFailedSubmissionAttemptsBeforeNativeCamera={0}
                >
                  {acuantCaptureComponent}
                  {children}
                </Provider>
              </AcuantContextProvider>
            </DeviceContext.Provider>
          </AnalyticsContext.Provider>
        );
      }
      const result = render(<TestComponent />);
      const user = userEvent.setup();
      const fileInput = result.container.querySelector('input[type="file"]');
      expect(fileInput).to.exist();
      await user.click(fileInput);
      expect(trackEvent).to.not.have.been.calledWith(
        'IdV: Native camera forced after failed attempts',
      );
    });
  });

  describe('Manual Capture After Failures', () => {
    describe('Per-side failure tracking', () => {
      it('tracks failed quality check attempts independently per document side', () => {
        const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
          wrapper: ({ children }) => (
            <Provider
              maxCaptureAttemptsBeforeNativeCamera={10}
              maxAttemptsBeforeManualCapture={3}
              manualCaptureAfterFailuresEnabled
            >
              {children}
            </Provider>
          ),
        });

        const metadata = {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        };

        // Increment front twice
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);

        // Increment back once
        result.current.onFailedQualityCheckAttempt('back', metadata);

        expect(result.current.failedQualityCheckAttempts.front).to.equal(2);
        expect(result.current.failedQualityCheckAttempts.back).to.equal(1);
        expect(result.current.failedQualityCheckAttempts.passport).to.equal(0);
      });

      it('resets counter for specific side without affecting other sides', () => {
        const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
          wrapper: ({ children }) => (
            <Provider
              maxCaptureAttemptsBeforeNativeCamera={10}
              maxAttemptsBeforeManualCapture={3}
              manualCaptureAfterFailuresEnabled
            >
              {children}
            </Provider>
          ),
        });

        const metadata = {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        };

        // Increment all sides
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('back', metadata);
        result.current.onFailedQualityCheckAttempt('passport', metadata);

        // Reset only front
        result.current.onResetFailedQualityCheckAttempts('front');

        expect(result.current.failedQualityCheckAttempts.front).to.equal(0);
        expect(result.current.failedQualityCheckAttempts.back).to.equal(1);
        expect(result.current.failedQualityCheckAttempts.passport).to.equal(1);
      });
    });

    describe('shouldTriggerManualCapture', () => {
      it('returns false when feature is disabled', () => {
        const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
          wrapper: ({ children }) => (
            <Provider
              maxCaptureAttemptsBeforeNativeCamera={10}
              maxAttemptsBeforeManualCapture={3}
              manualCaptureAfterFailuresEnabled={false}
            >
              {children}
            </Provider>
          ),
        });

        const metadata = {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        };

        // Increment front 3 times
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);

        expect(result.current.shouldTriggerManualCapture('front')).to.equal(false);
      });

      it('returns false when failures are below threshold', () => {
        const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
          wrapper: ({ children }) => (
            <Provider
              maxCaptureAttemptsBeforeNativeCamera={10}
              maxAttemptsBeforeManualCapture={3}
              manualCaptureAfterFailuresEnabled
            >
              {children}
            </Provider>
          ),
        });

        const metadata = {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        };

        // Increment front only twice (below threshold of 3)
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);

        expect(result.current.shouldTriggerManualCapture('front')).to.equal(false);
      });

      it('returns true when failures reach threshold and feature is enabled', () => {
        const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
          wrapper: ({ children }) => (
            <Provider
              maxCaptureAttemptsBeforeNativeCamera={10}
              maxAttemptsBeforeManualCapture={3}
              manualCaptureAfterFailuresEnabled
            >
              {children}
            </Provider>
          ),
        });

        const metadata = {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        };

        // Increment front 3 times (at threshold)
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);

        expect(result.current.shouldTriggerManualCapture('front')).to.equal(true);
      });

      it('returns true when failures exceed threshold', () => {
        const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
          wrapper: ({ children }) => (
            <Provider
              maxCaptureAttemptsBeforeNativeCamera={10}
              maxAttemptsBeforeManualCapture={3}
              manualCaptureAfterFailuresEnabled
            >
              {children}
            </Provider>
          ),
        });

        const metadata = {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        };

        // Increment front 5 times (exceeds threshold)
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);

        expect(result.current.shouldTriggerManualCapture('front')).to.equal(true);
      });

      it('only triggers for the side that reached threshold', () => {
        const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
          wrapper: ({ children }) => (
            <Provider
              maxCaptureAttemptsBeforeNativeCamera={10}
              maxAttemptsBeforeManualCapture={3}
              manualCaptureAfterFailuresEnabled
            >
              {children}
            </Provider>
          ),
        });

        const metadata = {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        };

        // Increment front 3 times, back only 2 times
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('back', metadata);
        result.current.onFailedQualityCheckAttempt('back', metadata);

        expect(result.current.shouldTriggerManualCapture('front')).to.equal(true);
        expect(result.current.shouldTriggerManualCapture('back')).to.equal(false);
        expect(result.current.shouldTriggerManualCapture('passport')).to.equal(false);
      });
    });

    describe('Configuration', () => {
      it('uses custom threshold when provided', () => {
        const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
          wrapper: ({ children }) => (
            <Provider
              maxCaptureAttemptsBeforeNativeCamera={10}
              maxAttemptsBeforeManualCapture={5}
              manualCaptureAfterFailuresEnabled
            >
              {children}
            </Provider>
          ),
        });

        const metadata = {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        };

        // Increment 4 times (below custom threshold of 5)
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);
        result.current.onFailedQualityCheckAttempt('front', metadata);

        expect(result.current.shouldTriggerManualCapture('front')).to.equal(false);

        // Increment one more time to reach threshold
        result.current.onFailedQualityCheckAttempt('front', metadata);

        expect(result.current.shouldTriggerManualCapture('front')).to.equal(true);
      });

      it('uses default threshold of 3 when not provided', () => {
        const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
          wrapper: ({ children }) => (
            <Provider maxCaptureAttemptsBeforeNativeCamera={10} manualCaptureAfterFailuresEnabled>
              {children}
            </Provider>
          ),
        });

        expect(result.current.maxAttemptsBeforeManualCapture).to.equal(3);
      });
    });
  });
});
