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
  const { captureAttempts, maxAttemptsBeforeTips, lastAttemptMetadata } = useContext(
    CaptureAttemptsContext,
  );
  const { isAssessedAsGlare, isAssessedAsBlurry } = lastAttemptMetadata;

  return captureAttempts >= maxAttemptsBeforeTips && !didShowTroubleshooting ? (
    <CaptureAdvice
      onTryAgain={() => setDidShowTroubleshooting(true)}
      isAssessedAsGlare={isAssessedAsGlare}
      isAssessedAsBlurry={isAssessedAsBlurry}
    />
  ) : (
    <>{children}</>
  );
}

export default CaptureAttemptsTroubleshooting;
