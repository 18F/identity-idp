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
 * @typedef CaptureAttemptsContext
 *
 * @prop {number} captureAttempts Current number of attempts.
 * @prop {(metadata: CaptureAttemptMetadata)=>void} onCaptureAttempt Callback to trigger on
 * attempt, to increment attempts.
 * @prop {number} maxAttemptsBeforeTips Number of failed attempts before showing tips.
 * @prop {CaptureAttemptMetadata} lastAttemptMetadata Metadata about the last attempt.
 */

/** @type {CaptureAttemptMetadata} */
const DEFAULT_LAST_ATTEMPT_METADATA = {
  isAssessedAsGlare: false,
  isAssessedAsBlurry: false,
};

const CaptureAttemptsContext = createContext(
  /** @type {CaptureAttemptsContext} */ ({
    captureAttempts: 0,
    onCaptureAttempt: () => {},
    maxAttemptsBeforeTips: Infinity,
    lastAttemptMetadata: DEFAULT_LAST_ATTEMPT_METADATA,
  }),
);

CaptureAttemptsContext.displayName = 'CaptureAttemptsContext';

/**
 * @typedef CaptureAttemptsContextProviderProps
 *
 * @prop {ReactNode} children
 * @prop {number} maxAttemptsBeforeTips
 */

/**
 * @param {CaptureAttemptsContextProviderProps} props
 */
function CaptureAttemptsContextProvider({ children, maxAttemptsBeforeTips }) {
  const [lastAttemptMetadata, setLastAttemptMetadata] = useState(
    /** @type {CaptureAttemptMetadata} */ (DEFAULT_LAST_ATTEMPT_METADATA),
  );
  const [captureAttempts, incrementCaptureAttempts] = useCounter(0);

  /**
   * @param {CaptureAttemptMetadata} metadata
   */
  function onCaptureAttempt(metadata) {
    incrementCaptureAttempts();
    setLastAttemptMetadata(metadata);
  }

  return (
    <CaptureAttemptsContext.Provider
      value={{ captureAttempts, onCaptureAttempt, maxAttemptsBeforeTips, lastAttemptMetadata }}
    >
      {children}
    </CaptureAttemptsContext.Provider>
  );
}

export default CaptureAttemptsContext;
export { CaptureAttemptsContextProvider as Provider };
