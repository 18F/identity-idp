import { createContext, useState } from 'react';
import useCounter from '../hooks/use-counter';

import type { ReactNode } from 'react';

interface CaptureAttemptMetadata {
  isAssessedAsGlare: boolean;
  isAssessedAsBlurry: boolean;
}

interface FailedCaptureAttemptsContextInterface {
  /**
   * Current number of failed capture attempts
   */
  failedCaptureAttempts: number;
  /**
   * Number of failed attempts before showing tips
   */
  maxFailedAttemptsBeforeTips: number;
  /**
   * The maximum number of failed Acuant capture attempts
   * before use of the native camera option is triggered
   */
  maxAttemptsBeforeNativeCamera: number;
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
   * after maxAttemptsBeforeNativeCamera number of failed attempts
   */
  forceNativeCamera: boolean;
}

const DEFAULT_LAST_ATTEMPT_METADATA: CaptureAttemptMetadata = {
  isAssessedAsGlare: false,
  isAssessedAsBlurry: false,
};

const FailedCaptureAttemptsContext = createContext<FailedCaptureAttemptsContextInterface>({
  failedCaptureAttempts: 0,
  onFailedCaptureAttempt: () => {},
  onResetFailedCaptureAttempts: () => {},
  maxAttemptsBeforeNativeCamera: Infinity,
  maxFailedAttemptsBeforeTips: Infinity,
  lastAttemptMetadata: DEFAULT_LAST_ATTEMPT_METADATA,
  forceNativeCamera: false,
});

FailedCaptureAttemptsContext.displayName = 'FailedCaptureAttemptsContext';

interface FailedCaptureAttemptsContextProviderProps {
  children: ReactNode;
  maxFailedAttemptsBeforeTips: number;
  maxAttemptsBeforeNativeCamera: number;
}

function FailedCaptureAttemptsContextProvider({
  children,
  maxFailedAttemptsBeforeTips,
  maxAttemptsBeforeNativeCamera,
}: FailedCaptureAttemptsContextProviderProps) {
  const [lastAttemptMetadata, setLastAttemptMetadata] = useState<CaptureAttemptMetadata>(
    DEFAULT_LAST_ATTEMPT_METADATA,
  );
  const [failedCaptureAttempts, incrementFailedCaptureAttempts, onResetFailedCaptureAttempts] =
    useCounter();

  function onFailedCaptureAttempt(metadata: CaptureAttemptMetadata) {
    incrementFailedCaptureAttempts();
    setLastAttemptMetadata(metadata);
  }

  const forceNativeCamera = failedCaptureAttempts >= maxAttemptsBeforeNativeCamera;

  return (
    <FailedCaptureAttemptsContext.Provider
      value={{
        failedCaptureAttempts,
        onFailedCaptureAttempt,
        onResetFailedCaptureAttempts,
        maxAttemptsBeforeNativeCamera,
        maxFailedAttemptsBeforeTips,
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
