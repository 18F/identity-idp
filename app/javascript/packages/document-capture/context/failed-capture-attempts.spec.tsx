import { useContext } from 'react';
import { renderHook, act } from '@testing-library/react-hooks';
import type { ComponentType } from 'react';
import FailedCaptureAttemptsContext, {
  Provider as FailedCaptureAttemptsContextProvider,
} from './failed-capture-attempts';
import SelfieCaptureContext from './selfie-capture';

describe('FailedCaptureAttemptsContextProvider', () => {
  let wrapper: ComponentType;

  beforeEach(() => {
    wrapper = ({ children }) => (
      <SelfieCaptureContext.Provider
        value={{
          isSelfieCaptureEnabled: false,
          isUploadEnabled: true,
          isSelfieDesktopTestMode: false,
          showHelpInitially: false,
        }}
      >
        <FailedCaptureAttemptsContextProvider
          maxCaptureAttemptsBeforeNativeCamera={10}
          maxSubmissionAttemptsBeforeNativeCamera={5}
          failedFingerprints={{ front: [], back: [], passport: [] }}
          maxAttemptsBeforeManualCapture={3}
          manualCaptureAfterFailuresEnabled
        >
          {children}
        </FailedCaptureAttemptsContextProvider>
      </SelfieCaptureContext.Provider>
    );
  });

  describe('per-side quality check failure tracking', () => {
    it('provides default failedQualityCheckAttempts', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      expect(result.current.failedQualityCheckAttempts).to.deep.equal({
        front: 0,
        back: 0,
        passport: 0,
      });
    });

    it('increments failed quality check attempts for front side', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
      });

      expect(result.current.failedQualityCheckAttempts.front).to.equal(1);
      expect(result.current.failedQualityCheckAttempts.back).to.equal(0);
      expect(result.current.failedQualityCheckAttempts.passport).to.equal(0);
    });

    it('increments failed quality check attempts for back side', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        result.current.onFailedQualityCheckAttempt('back', {
          isAssessedAsGlare: false,
          isAssessedAsBlurry: true,
          isAssessedAsUnsupported: false,
        });
      });

      expect(result.current.failedQualityCheckAttempts.front).to.equal(0);
      expect(result.current.failedQualityCheckAttempts.back).to.equal(1);
      expect(result.current.failedQualityCheckAttempts.passport).to.equal(0);
    });

    it('increments failed quality check attempts for passport side', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        result.current.onFailedQualityCheckAttempt('passport', {
          isAssessedAsGlare: false,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: true,
        });
      });

      expect(result.current.failedQualityCheckAttempts.front).to.equal(0);
      expect(result.current.failedQualityCheckAttempts.back).to.equal(0);
      expect(result.current.failedQualityCheckAttempts.passport).to.equal(1);
    });

    it('increments multiple times for the same side', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: false,
          isAssessedAsBlurry: true,
          isAssessedAsUnsupported: false,
        });
      });

      expect(result.current.failedQualityCheckAttempts.front).to.equal(3);
    });

    it('resets failed quality check attempts for a specific side', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('back', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
      });

      expect(result.current.failedQualityCheckAttempts.front).to.equal(2);
      expect(result.current.failedQualityCheckAttempts.back).to.equal(1);

      act(() => {
        result.current.onResetFailedQualityCheckAttempts('front');
      });

      expect(result.current.failedQualityCheckAttempts.front).to.equal(0);
      expect(result.current.failedQualityCheckAttempts.back).to.equal(1);
    });
  });

  describe('shouldTriggerManualCapture', () => {
    it('returns false when manual capture feature is disabled', () => {
      const disabledWrapper: ComponentType = ({ children }) => (
        <SelfieCaptureContext.Provider
          value={{
            isSelfieCaptureEnabled: false,
            isUploadEnabled: true,
            isSelfieDesktopTestMode: false,
            showHelpInitially: false,
          }}
        >
          <FailedCaptureAttemptsContextProvider
            maxCaptureAttemptsBeforeNativeCamera={10}
            maxSubmissionAttemptsBeforeNativeCamera={5}
            failedFingerprints={{ front: [], back: [], passport: [] }}
            maxAttemptsBeforeManualCapture={3}
            manualCaptureAfterFailuresEnabled={false}
          >
            {children}
          </FailedCaptureAttemptsContextProvider>
        </SelfieCaptureContext.Provider>
      );

      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
        wrapper: disabledWrapper,
      });

      act(() => {
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
      });

      expect(result.current.shouldTriggerManualCapture('front')).to.be.false();
    });

    it('returns false when attempts are below threshold', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
      });

      expect(result.current.shouldTriggerManualCapture('front')).to.be.false();
    });

    it('returns true when attempts reach threshold', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
      });

      expect(result.current.shouldTriggerManualCapture('front')).to.be.true();
    });

    it('returns true when attempts exceed threshold', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
      });

      expect(result.current.shouldTriggerManualCapture('front')).to.be.true();
    });

    it('checks each side independently', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('back', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
      });

      expect(result.current.shouldTriggerManualCapture('front')).to.be.true();
      expect(result.current.shouldTriggerManualCapture('back')).to.be.false();
      expect(result.current.shouldTriggerManualCapture('passport')).to.be.false();
    });
  });

  describe('forceNativeCamera calculation', () => {
    it('does not include quality check failures in forceNativeCamera calculation', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        // Add 5 quality check failures for front side
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
        result.current.onFailedQualityCheckAttempt('front', {
          isAssessedAsGlare: true,
          isAssessedAsBlurry: false,
          isAssessedAsUnsupported: false,
        });
      });

      // forceNativeCamera should still be false because quality check failures don't count
      expect(result.current.forceNativeCamera).to.be.false();
    });

    it('triggers forceNativeCamera based on capture attempts threshold', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        // Add 10 capture failures to reach maxCaptureAttemptsBeforeNativeCamera
        for (let i = 0; i < 10; i++) {
          result.current.onFailedCaptureAttempt({
            isAssessedAsGlare: false,
            isAssessedAsBlurry: false,
            isAssessedAsUnsupported: false,
          });
        }
      });

      expect(result.current.forceNativeCamera).to.be.true();
    });

    it('triggers forceNativeCamera based on submission attempts threshold', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      act(() => {
        // Add 5 submission failures to reach maxSubmissionAttemptsBeforeNativeCamera
        for (let i = 0; i < 5; i++) {
          result.current.onFailedSubmissionAttempt({ front: [], back: [], passport: [] });
        }
      });

      expect(result.current.forceNativeCamera).to.be.true();
    });
  });

  describe('context values', () => {
    it('provides maxAttemptsBeforeManualCapture', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      expect(result.current.maxAttemptsBeforeManualCapture).to.equal(3);
    });

    it('provides manualCaptureAfterFailuresEnabled', () => {
      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), { wrapper });

      expect(result.current.manualCaptureAfterFailuresEnabled).to.be.true();
    });

    it('uses default value for maxAttemptsBeforeManualCapture when not provided', () => {
      const defaultWrapper: ComponentType = ({ children }) => (
        <SelfieCaptureContext.Provider
          value={{
            isSelfieCaptureEnabled: false,
            isUploadEnabled: true,
            isSelfieDesktopTestMode: false,
            showHelpInitially: false,
          }}
        >
          <FailedCaptureAttemptsContextProvider
            maxCaptureAttemptsBeforeNativeCamera={10}
            maxSubmissionAttemptsBeforeNativeCamera={5}
            failedFingerprints={{ front: [], back: [], passport: [] }}
          >
            {children}
          </FailedCaptureAttemptsContextProvider>
        </SelfieCaptureContext.Provider>
      );

      const { result } = renderHook(() => useContext(FailedCaptureAttemptsContext), {
        wrapper: defaultWrapper,
      });

      expect(result.current.maxAttemptsBeforeManualCapture).to.equal(3);
      expect(result.current.manualCaptureAfterFailuresEnabled).to.be.false();
    });
  });
});
