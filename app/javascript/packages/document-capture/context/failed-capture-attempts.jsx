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
 * @prop {CaptureAttemptMetadata} lastAttemptMetadata Metadata about the last attempt.
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
    maxFailedAttemptsBeforeTips: Infinity,
    lastAttemptMetadata: DEFAULT_LAST_ATTEMPT_METADATA,
  }),
);

FailedCaptureAttemptsContext.displayName = 'FailedCaptureAttemptsContext';

/**
 * @typedef FailedCaptureAttemptsContextProviderProps
 *
 * @prop {ReactNode} children
 * @prop {number} maxFailedAttemptsBeforeTips
 */

/**
 * @param {FailedCaptureAttemptsContextProviderProps} props
 */
function FailedCaptureAttemptsContextProvider({ children, maxFailedAttemptsBeforeTips }) {
  const [lastAttemptMetadata, setLastAttemptMetadata] = useState(
    /** @type {CaptureAttemptMetadata} */ (DEFAULT_LAST_ATTEMPT_METADATA),
  );
  const [failedCaptureAttempts, incrementFailedCaptureAttempts, onResetFailedCaptureAttempts] =
    useCounter();

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
        maxFailedAttemptsBeforeTips,
        lastAttemptMetadata,
      }}
    >
      {children}
    </FailedCaptureAttemptsContext.Provider>
  );
}

export default FailedCaptureAttemptsContext;
export { FailedCaptureAttemptsContextProvider as Provider };
