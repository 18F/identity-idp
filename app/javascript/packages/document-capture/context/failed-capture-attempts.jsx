import { createContext, useState } from 'react';
import useCounter from '../hooks/use-counter';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef CaptureAttemptMetadata
 *
 * @prop {boolean} isAssessedAsGlare
 * @prop {boolean} isAssessedAsBlurry
 */

/**
 * @typedef FailedCaptureAttemptsContext
 *
 * @prop {number} failedCaptureAttempts Current number of failed attempts.
 * @prop {(metadata: CaptureAttemptMetadata)=>void} onFailedCaptureAttempt Callback to trigger on
 * attempt, to increment attempts.
 * @prop {() => void} onResetFailedCaptureAttempts Callback to trigger a reset of attempts.
 * @prop {number} maxFailedAttemptsBeforeTips Number of failed attempts before showing tips.
 * @prop {number} maxAttemptsBeforeNativeCamera Number of attempts before forcing the use of the native camera (if available)
 * @prop {CaptureAttemptMetadata} lastAttemptMetadata Metadata about the last attempt.
 * @prop {boolean} forceNativeCamera Whether or not to force use of the native camera. Is set to true if the number of failedCaptureAttempts is equal to or greater than maxAttemptsBeforeNativeCamera
 */

/** @type {CaptureAttemptMetadata} */
const DEFAULT_LAST_ATTEMPT_METADATA = {
  isAssessedAsGlare: false,
  isAssessedAsBlurry: false,
};

const FailedCaptureAttemptsContext = createContext(
  /** @type {FailedCaptureAttemptsContext} */ ({
    failedCaptureAttempts: 0,
    onFailedCaptureAttempt: () => {},
    onResetFailedCaptureAttempts: () => {},
    maxAttemptsBeforeNativeCamera: Infinity,
    maxFailedAttemptsBeforeTips: Infinity,
    lastAttemptMetadata: DEFAULT_LAST_ATTEMPT_METADATA,
    forceNativeCamera: false,
  }),
);

FailedCaptureAttemptsContext.displayName = 'FailedCaptureAttemptsContext';

/**
 * @typedef FailedCaptureAttemptsContextProviderProps
 *
 * @prop {ReactNode} children
 * @prop {number} maxFailedAttemptsBeforeTips
 * @prop {number} maxAttemptsBeforeNativeCamera
 */

/**
 * @param {FailedCaptureAttemptsContextProviderProps} props
 */
function FailedCaptureAttemptsContextProvider({
  children,
  maxFailedAttemptsBeforeTips,
  maxAttemptsBeforeNativeCamera,
}) {
  const [lastAttemptMetadata, setLastAttemptMetadata] = useState(
    /** @type {CaptureAttemptMetadata} */ (DEFAULT_LAST_ATTEMPT_METADATA),
  );
  const [failedCaptureAttempts, incrementFailedCaptureAttempts, onResetFailedCaptureAttempts] =
    useCounter();

  const forceNativeCamera = failedCaptureAttempts >= maxAttemptsBeforeNativeCamera;

  /**
   * @param {CaptureAttemptMetadata} metadata
   */
  function onFailedCaptureAttempt(metadata) {
    incrementFailedCaptureAttempts();
    setLastAttemptMetadata(metadata);
  }

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
