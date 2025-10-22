import { createContext, useContext, useState } from 'react';
import type { ReactNode } from 'react';
import useCounter from '../hooks/use-counter';
import SelfieCaptureContext from './selfie-capture';

interface CaptureAttemptMetadata {
  isAssessedAsGlare: boolean;
  isAssessedAsBlurry: boolean;
  isAssessedAsUnsupported: boolean;
}

interface UploadedImageFingerprints {
  /**
   * array url safe encoded base64  sha256 digest
   */
  front: string[] | null;
  back: string[] | null;
  passport: string[] | null;
}

/**
 * Document sides that support manual capture.
 * Note: Selfie is excluded because PassiveLiveness SDK does not support
 * manual capture mode and we need to preserve liveness detection.
 */
type DocumentSide = 'front' | 'back' | 'passport';

interface PerSideFailedAttempts {
  front: number;
  back: number;
  passport: number;
}

interface FailedCaptureAttemptsContextInterface {
  /**
   * Current number of failed capture attempts
   */
  failedCaptureAttempts: number;

  /**
   * Current number of failed submission attempts
   */
  failedSubmissionAttempts: number;

  /**
   * There's a bug with Safari on iOS where if you deny camera permissions
   * three times the prompt stops appearing. To avoid this we keep track
   * and force a full page reload on the third time.
   */
  failedCameraPermissionAttempts: number;

  /**
   * Callback when submission attempt fails.
   * Used to increment the failedSubmissionAttempts
   */
  onFailedSubmissionAttempt: (failedImageFingerprints: UploadedImageFingerprints) => void;

  /**
   * A wrapper around incrementFailedCameraPermissionAttempts
   */
  onFailedCameraPermissionAttempt: () => void;

  /**
   * The maximum number of failed Acuant capture attempts
   * before use of the native camera option is triggered
   */
  maxCaptureAttemptsBeforeNativeCamera: number;

  /**
   * The maximum number of failed document submission
   * attempts before use of the native camera option
   * is triggered
   */
  maxSubmissionAttemptsBeforeNativeCamera: number;

  /**
   * Callback triggered on attempt, to increment attempts
   */
  onFailedCaptureAttempt: (metadata: CaptureAttemptMetadata) => void;

  /**
   * Callback to trigger a reset of attempts
   */
  onResetFailedCaptureAttempts: () => void;

  /**
   * Metadata about the last attempt
   */
  lastAttemptMetadata: CaptureAttemptMetadata;

  /**
   * Whether or not the native camera is currently being forced
   * after maxCaptureAttemptsBeforeNativeCamera number of failed attempts
   */
  forceNativeCamera: boolean;

  failedSubmissionImageFingerprints: UploadedImageFingerprints;

  /**
   * Per-side failed quality check attempts for manual capture trigger
   * (front, back, passport only - selfie excluded to preserve liveness)
   */
  failedQualityCheckAttempts: PerSideFailedAttempts;

  /**
   * Callback to increment failed quality check attempts for a specific side
   */
  onFailedQualityCheckAttempt: (side: DocumentSide, metadata: CaptureAttemptMetadata) => void;

  /**
   * Callback to reset failed quality check attempts for a specific side
   */
  onResetFailedQualityCheckAttempts: (side: DocumentSide) => void;

  /**
   * Check if manual capture should be triggered for a specific side
   */
  shouldTriggerManualCapture: (side: DocumentSide) => boolean;

  /**
   * Maximum number of failed quality check attempts before manual capture is triggered
   */
  maxAttemptsBeforeManualCapture: number;

  /**
   * Whether the manual capture after failures feature is enabled (A/B test)
   */
  manualCaptureAfterFailuresEnabled: boolean;
}

const DEFAULT_LAST_ATTEMPT_METADATA: CaptureAttemptMetadata = {
  isAssessedAsGlare: false,
  isAssessedAsBlurry: false,
  isAssessedAsUnsupported: false,
};

const DEFAULT_PER_SIDE_FAILED_ATTEMPTS: PerSideFailedAttempts = {
  front: 0,
  back: 0,
  passport: 0,
};

const FailedCaptureAttemptsContext = createContext<FailedCaptureAttemptsContextInterface>({
  failedCaptureAttempts: 0,
  failedSubmissionAttempts: 0,
  failedCameraPermissionAttempts: 0,
  onFailedCaptureAttempt: () => {},
  onFailedSubmissionAttempt: () => {},
  onFailedCameraPermissionAttempt: () => {},
  onResetFailedCaptureAttempts: () => {},
  maxCaptureAttemptsBeforeNativeCamera: Infinity,
  maxSubmissionAttemptsBeforeNativeCamera: Infinity,
  lastAttemptMetadata: DEFAULT_LAST_ATTEMPT_METADATA,
  forceNativeCamera: false,
  failedSubmissionImageFingerprints: { front: [], back: [], passport: [] },
  failedQualityCheckAttempts: DEFAULT_PER_SIDE_FAILED_ATTEMPTS,
  onFailedQualityCheckAttempt: () => {},
  onResetFailedQualityCheckAttempts: () => {},
  shouldTriggerManualCapture: () => false,
  maxAttemptsBeforeManualCapture: 3,
  manualCaptureAfterFailuresEnabled: false,
});

FailedCaptureAttemptsContext.displayName = 'FailedCaptureAttemptsContext';

interface FailedCaptureAttemptsContextProviderProps {
  children: ReactNode;
  maxCaptureAttemptsBeforeNativeCamera: number;
  maxSubmissionAttemptsBeforeNativeCamera: number;
  failedFingerprints: { front: []; back: []; passport: [] };
  maxAttemptsBeforeManualCapture?: number;
  manualCaptureAfterFailuresEnabled?: boolean;
}

function FailedCaptureAttemptsContextProvider({
  children,
  maxCaptureAttemptsBeforeNativeCamera,
  maxSubmissionAttemptsBeforeNativeCamera,
  failedFingerprints = { front: [], back: [], passport: [] },
  maxAttemptsBeforeManualCapture = 3,
  manualCaptureAfterFailuresEnabled = false,
}: FailedCaptureAttemptsContextProviderProps) {
  const [lastAttemptMetadata, setLastAttemptMetadata] = useState<CaptureAttemptMetadata>(
    DEFAULT_LAST_ATTEMPT_METADATA,
  );
  const [failedCaptureAttempts, incrementFailedCaptureAttempts, onResetFailedCaptureAttempts] =
    useCounter();
  const [failedSubmissionAttempts, incrementFailedSubmissionAttempts] = useCounter();
  const [failedCameraPermissionAttempts, incrementFailedCameraPermissionAttempts] = useCounter();
  const { isSelfieCaptureEnabled } = useContext(SelfieCaptureContext);

  const [failedSubmissionImageFingerprints, setFailedSubmissionImageFingerprints] =
    useState<UploadedImageFingerprints>(failedFingerprints);

  const [failedQualityCheckAttempts, setFailedQualityCheckAttempts] =
    useState<PerSideFailedAttempts>(DEFAULT_PER_SIDE_FAILED_ATTEMPTS);

  function onFailedCaptureAttempt(metadata: CaptureAttemptMetadata) {
    incrementFailedCaptureAttempts();
    setLastAttemptMetadata(metadata);
  }

  function onFailedSubmissionAttempt(failedOnes: UploadedImageFingerprints) {
    incrementFailedSubmissionAttempts();
    setFailedSubmissionImageFingerprints(failedOnes);
  }

  function onFailedCameraPermissionAttempt() {
    incrementFailedCameraPermissionAttempts();
  }

  function onFailedQualityCheckAttempt(side: DocumentSide, metadata: CaptureAttemptMetadata) {
    setFailedQualityCheckAttempts((prev) => ({
      ...prev,
      [side]: prev[side] + 1,
    }));
    setLastAttemptMetadata(metadata);
  }

  function onResetFailedQualityCheckAttempts(side: DocumentSide) {
    setFailedQualityCheckAttempts((prev) => ({
      ...prev,
      [side]: 0,
    }));
  }

  function shouldTriggerManualCapture(side: DocumentSide): boolean {
    if (!manualCaptureAfterFailuresEnabled) {
      return false;
    }
    return failedQualityCheckAttempts[side] >= maxAttemptsBeforeManualCapture;
  }

  const hasExhaustedAttempts =
    failedCaptureAttempts >= maxCaptureAttemptsBeforeNativeCamera ||
    failedSubmissionAttempts >= maxSubmissionAttemptsBeforeNativeCamera;

  const forceNativeCamera = isSelfieCaptureEnabled ? false : hasExhaustedAttempts;

  return (
    <FailedCaptureAttemptsContext.Provider
      value={{
        failedCaptureAttempts,
        onFailedCaptureAttempt,
        onResetFailedCaptureAttempts,
        failedSubmissionAttempts,
        onFailedSubmissionAttempt,
        failedCameraPermissionAttempts,
        onFailedCameraPermissionAttempt,
        maxCaptureAttemptsBeforeNativeCamera,
        maxSubmissionAttemptsBeforeNativeCamera,
        lastAttemptMetadata,
        forceNativeCamera,
        failedSubmissionImageFingerprints,
        failedQualityCheckAttempts,
        onFailedQualityCheckAttempt,
        onResetFailedQualityCheckAttempts,
        shouldTriggerManualCapture,
        maxAttemptsBeforeManualCapture,
        manualCaptureAfterFailuresEnabled,
      }}
    >
      {children}
    </FailedCaptureAttemptsContext.Provider>
  );
}

export default FailedCaptureAttemptsContext;
export { FailedCaptureAttemptsContextProvider as Provider };
export type { UploadedImageFingerprints, DocumentSide };
