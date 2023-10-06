import { createContext, useState } from 'react';
import type { ReactNode } from 'react';
import useCounter from '../hooks/use-counter';

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
}

const DEFAULT_LAST_ATTEMPT_METADATA: CaptureAttemptMetadata = {
  isAssessedAsGlare: false,
  isAssessedAsBlurry: false,
  isAssessedAsUnsupported: false,
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
  failedSubmissionImageFingerprints: { front: [], back: [] },
});

FailedCaptureAttemptsContext.displayName = 'FailedCaptureAttemptsContext';

interface FailedCaptureAttemptsContextProviderProps {
  children: ReactNode;
  maxCaptureAttemptsBeforeNativeCamera: number;
  maxSubmissionAttemptsBeforeNativeCamera: number;
  failedFingerprints: { front: []; back: [] };
}

function FailedCaptureAttemptsContextProvider({
  children,
  maxCaptureAttemptsBeforeNativeCamera,
  maxSubmissionAttemptsBeforeNativeCamera,
  failedFingerprints = { front: [], back: [] },
}: FailedCaptureAttemptsContextProviderProps) {
  const [lastAttemptMetadata, setLastAttemptMetadata] = useState<CaptureAttemptMetadata>(
    DEFAULT_LAST_ATTEMPT_METADATA,
  );
  const [failedCaptureAttempts, incrementFailedCaptureAttempts, onResetFailedCaptureAttempts] =
    useCounter();
  const [failedSubmissionAttempts, incrementFailedSubmissionAttempts] = useCounter();
  const [failedCameraPermissionAttempts, incrementFailedCameraPermissionAttempts] = useCounter();

  const [failedSubmissionImageFingerprints, setFailedSubmissionImageFingerprints] =
    useState<UploadedImageFingerprints>(failedFingerprints);

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

  const forceNativeCamera =
    failedCaptureAttempts >= maxCaptureAttemptsBeforeNativeCamera ||
    failedSubmissionAttempts >= maxSubmissionAttemptsBeforeNativeCamera;

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
      }}
    >
      {children}
    </FailedCaptureAttemptsContext.Provider>
  );
}

export default FailedCaptureAttemptsContext;
export { FailedCaptureAttemptsContextProvider as Provider };
export { UploadedImageFingerprints };
