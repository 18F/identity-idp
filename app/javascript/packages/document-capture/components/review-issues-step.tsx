import { useContext, useEffect, useState } from 'react';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { FormStepsContext } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import type { PII } from '../services/upload';
import AnalyticsContext from '../context/analytics';
import BarcodeAttentionWarning from './barcode-attention-warning';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';
import DocumentCaptureWarning from './document-capture-warning';
import DocumentCaptureReviewIssues from './document-capture-review-issues';

// @ts-ignore
type JSONObject = Record<string, string | number | boolean | null | JSONObject>;
interface ReviewIssuesStepValue {
  /**
   * Front image value.
   */
  front: Blob | string | null | undefined;

  /**
   * Back image value.
   */
  back: Blob | string | null | undefined;

  /**
   * Front image metadata.
   */
  front_image_metadata?: JSONObject;

  /**
   * Back image metadata.
   */
  back_image_metadata?: JSONObject;
}

interface ReviewIssuesStepProps extends FormStepComponentProps<ReviewIssuesStepValue> {
  remainingAttempts?: number;

  isFailedResult?: boolean;

  isFailedDocType?: boolean;

  captureHints?: boolean;

  pii?: PII;

  failedImageFingerprints?: { front: string[] | null; back: string[] | null };
}

function ReviewIssuesStep({
  value = {},
  onChange = () => {},
  errors = [],
  unknownFieldErrors = [],
  onError = () => {},
  registerField = () => undefined,
  remainingAttempts = Infinity,
  isFailedResult = false,
  isFailedDocType = false,
  pii,
  captureHints = false,
  failedImageFingerprints = { front: [], back: [] },
}: ReviewIssuesStepProps) {
  const { trackEvent } = useContext(AnalyticsContext);
  const [hasDismissed, setHasDismissed] = useState(remainingAttempts === Infinity);
  const { onPageTransition, changeStepCanComplete } = useContext(FormStepsContext);
  useDidUpdateEffect(onPageTransition, [hasDismissed]);

  const { onFailedSubmissionAttempt } = useContext(FailedCaptureAttemptsContext);
  useEffect(() => onFailedSubmissionAttempt(failedImageFingerprints), [failedImageFingerprints]);

  function onWarningPageDismissed() {
    trackEvent('IdV: Capture troubleshooting dismissed');

    setHasDismissed(true);
  }

  const [skipWarning] = useState<boolean>(
    !!failedImageFingerprints?.front?.includes(value.front_image_metadata?.fingerprint) ||
      !!failedImageFingerprints?.back?.includes(value.back_image_metadata?.fingerprint),
  );

  // let FormSteps know, via FormStepsContext, whether this page
  // is ready to submit form values
  useEffect(() => {
    changeStepCanComplete(!!hasDismissed);
  }, [hasDismissed]);

  if (!hasDismissed && pii) {
    return <BarcodeAttentionWarning onDismiss={onWarningPageDismissed} pii={pii} />;
  }
  // Show warning screen
  if (!hasDismissed && !skipWarning) {
    // Warning(try again screen)
    return (
      <DocumentCaptureWarning
        isFailedDocType={isFailedDocType}
        isFailedResult={isFailedResult}
        remainingAttempts={remainingAttempts}
        unknownFieldErrors={unknownFieldErrors}
        actionOnClick={onWarningPageDismissed}
        hasDismissed={false}
      />
    );
  }
  // Show review issue screen, hasDismissed = true
  return (
    <DocumentCaptureReviewIssues
      isFailedDocType={isFailedDocType}
      remainingAttempts={remainingAttempts}
      captureHints={captureHints}
      value={value}
      unknownFieldErrors={unknownFieldErrors}
      registerField={registerField}
      errors={errors}
      onChange={onChange}
      onError={onError}
      hasDismissed
    />
  );
}

export default ReviewIssuesStep;
