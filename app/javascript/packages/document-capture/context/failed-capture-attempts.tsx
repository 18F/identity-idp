import { createContext, useState } from 'react';
import type { ReactNode } from 'react';
import useCounter from '../hooks/use-counter';

interface CaptureAttemptMetadata {
  isAssessedAsGlare: boolean;
  isAssessedAsBlurry: boolean;
  isAssessedAsUnsupported: boolean;
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
   * Callback when submission attempt fails.
   * Used to increment the failedSubmissionAttempts
   */
  onFailedSubmissionAttempt: () => void;

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
}

const DEFAULT_LAST_ATTEMPT_METADATA: CaptureAttemptMetadata = {
  isAssessedAsGlare: false,
  isAssessedAsBlurry: false,
  isAssessedAsUnsupported: false,
};

const FailedCaptureAttemptsContext = createContext<FailedCaptureAttemptsContextInterface>({
  failedCaptureAttempts: 0,
  failedSubmissionAttempts: 0,
  onFailedCaptureAttempt: () => {},
  onFailedSubmissionAttempt: () => {},
  onResetFailedCaptureAttempts: () => {},
  maxCaptureAttemptsBeforeNativeCamera: Infinity,
  maxSubmissionAttemptsBeforeNativeCamera: Infinity,
  lastAttemptMetadata: DEFAULT_LAST_ATTEMPT_METADATA,
  forceNativeCamera: false,
});

FailedCaptureAttemptsContext.displayName = 'FailedCaptureAttemptsContext';

interface FailedCaptureAttemptsContextProviderProps {
  children: ReactNode;
  maxCaptureAttemptsBeforeNativeCamera: number;
  maxSubmissionAttemptsBeforeNativeCamera: number;
}

function FailedCaptureAttemptsContextProvider({
  children,
  maxCaptureAttemptsBeforeNativeCamera,
  maxSubmissionAttemptsBeforeNativeCamera,
}: FailedCaptureAttemptsContextProviderProps) {
  const [lastAttemptMetadata, setLastAttemptMetadata] = useState<CaptureAttemptMetadata>(
    DEFAULT_LAST_ATTEMPT_METADATA,
  );
  const [failedCaptureAttempts, incrementFailedCaptureAttempts, onResetFailedCaptureAttempts] =
    useCounter();
  const [failedSubmissionAttempts, incrementFailedSubmissionAttempts] = useCounter();

  function onFailedCaptureAttempt(metadata: CaptureAttemptMetadata) {
    incrementFailedCaptureAttempts();
    setLastAttemptMetadata(metadata);
  }

  function onFailedSubmissionAttempt() {
    incrementFailedSubmissionAttempts();
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
        maxCaptureAttemptsBeforeNativeCamera,
        maxSubmissionAttemptsBeforeNativeCamera,
        lastAttemptMetadata,
        forceNativeCamera,
      }}
    >
      {children}
    </FailedCaptureAttemptsContext.Provider>
  );
}

export default FailedCaptureAttemptsContext;
export { FailedCaptureAttemptsContextProvider as Provider };
