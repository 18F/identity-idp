import { useContext, useState } from 'react';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';
import CaptureAdvice from './capture-advice';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef CaptureTroubleshootingProps
 *
 * @prop {ReactNode} children
 */

/**
 * @param {CaptureTroubleshootingProps} props
 */
function CaptureTroubleshooting({ children }) {
  const [didShowTroubleshooting, setDidShowTroubleshooting] = useState(false);
  const { failedCaptureAttempts, maxFailedAttemptsBeforeTips, lastAttemptMetadata } = useContext(
    FailedCaptureAttemptsContext,
  );
  const { isAssessedAsGlare, isAssessedAsBlurry } = lastAttemptMetadata;

  return failedCaptureAttempts >= maxFailedAttemptsBeforeTips && !didShowTroubleshooting ? (
    <CaptureAdvice
      onTryAgain={() => setDidShowTroubleshooting(true)}
      isAssessedAsGlare={isAssessedAsGlare}
      isAssessedAsBlurry={isAssessedAsBlurry}
    />
  ) : (
    <>{children}</>
  );
}

export default CaptureTroubleshooting;
