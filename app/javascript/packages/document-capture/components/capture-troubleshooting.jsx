import { useContext, useState } from 'react';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';
import CallbackOnMount from './callback-on-mount';
import CaptureAdvice from './capture-advice';
import { FormStepsContext } from './form-steps';
import useDidUpdateEffect from '../hooks/use-did-update-effect';

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
  const { onContentReplaced } = useContext(FormStepsContext);
  useDidUpdateEffect(onContentReplaced, [didShowTroubleshooting]);
  const { isAssessedAsGlare, isAssessedAsBlurry } = lastAttemptMetadata;

  return failedCaptureAttempts >= maxFailedAttemptsBeforeTips && !didShowTroubleshooting ? (
    <CallbackOnMount onMount={onContentReplaced}>
      <CaptureAdvice
        onTryAgain={() => setDidShowTroubleshooting(true)}
        isAssessedAsGlare={isAssessedAsGlare}
        isAssessedAsBlurry={isAssessedAsBlurry}
      />
    </CallbackOnMount>
  ) : (
    <>{children}</>
  );
}

export default CaptureTroubleshooting;
