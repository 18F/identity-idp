import { createContext } from 'react';
import useCounter from '../hooks/use-counter';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef CaptureAttemptsContext
 *
 * @prop {number} captureAttempts Current number of attempts.
 * @prop {()=>void} onCaptureAttempt Callback to trigger on attempt, to increment attempts.
 * @prop {number} maxAttemptsBeforeTips Number of failed attempts before showing tips.
 */

const CaptureAttemptsContext = createContext(
  /** @type {CaptureAttemptsContext} */ ({
    captureAttempts: 0,
    onCaptureAttempt: () => {},
    maxAttemptsBeforeTips: Infinity,
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
  const [captureAttempts, onCaptureAttempt] = useCounter(0);

  return (
    <CaptureAttemptsContext.Provider
      value={{ captureAttempts, onCaptureAttempt, maxAttemptsBeforeTips }}
    >
      {children}
    </CaptureAttemptsContext.Provider>
  );
}

export default CaptureAttemptsContext;
export { CaptureAttemptsContextProvider as Provider };
