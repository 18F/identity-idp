import { useContext, useState } from 'react';
import CaptureAttemptsContext from '../context/capture-attempts';
import CaptureAdvice from './capture-advice';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef CaptureAttemptsTroubleshootingProps
 *
 * @prop {ReactNode} children
 */

/**
 * @param {CaptureAttemptsTroubleshootingProps} props
 */
function CaptureAttemptsTroubleshooting({ children }) {
  const [didShowTroubleshooting, setDidShowTroubleshooting] = useState(false);
  const { captureAttempts, maxAttemptsBeforeTips } = useContext(CaptureAttemptsContext);

  return captureAttempts >= maxAttemptsBeforeTips && !didShowTroubleshooting ? (
    <CaptureAdvice onTryAgain={() => setDidShowTroubleshooting(true)} />
  ) : (
    <>{children}</>
  );
}

export default CaptureAttemptsTroubleshooting;
