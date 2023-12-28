import { useContext, useEffect, useLayoutEffect, useState } from 'react';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { FormStepsContext } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import type { PII } from '../services/upload';
import AnalyticsContext from '../context/analytics';
import BarcodeAttentionWarning from './barcode-attention-warning';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';
import DocumentCaptureWarning from './document-capture-warning';
import DocumentCaptureReviewIssues from './document-capture-review-issues';

export interface ReviewIssuesStepValue {
  /**
   * Front image value.
   */
  front?: Blob | string | null | undefined;

  /**
   * Back image value.
   */
  back?: Blob | string | null | undefined;

  /**
   * Selfie image value.
   */
  selfie?: Blob | string | null | undefined;

  /**
   * Front image metadata.
   */
  front_image_metadata?: string;
  /**
   * Back image metadata.
   */
  back_image_metadata?: string;
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
  const [skipWarning, setSkipWarning] = useState(false);
  useDidUpdateEffect(onPageTransition, [hasDismissed]);

  const { onFailedSubmissionAttempt, failedSubmissionImageFingerprints } = useContext(
    FailedCaptureAttemptsContext,
  );
  useEffect(() => onFailedSubmissionAttempt(failedImageFingerprints), []);

  useLayoutEffect(() => {
    let frontMetaData: { fingerprint: string | null } = { fingerprint: null };
    try {
      frontMetaData = JSON.parse(
        typeof value.front_image_metadata === 'undefined' ? '{}' : value.front_image_metadata,
      );
    } catch (e) {}
    const frontHasFailed = !!failedSubmissionImageFingerprints?.front?.includes(
      frontMetaData?.fingerprint ?? '',
    );

    let backMetaData: { fingerprint: string | null } = { fingerprint: null };
    try {
      backMetaData = JSON.parse(
        typeof value.back_image_metadata === 'undefined' ? '{}' : value.back_image_metadata,
      );
    } catch (e) {}
    const backHasFailed = !!failedSubmissionImageFingerprints?.back?.includes(
      backMetaData?.fingerprint ?? '',
    );
    if (frontHasFailed || backHasFailed) {
      setSkipWarning(true);
    }
  }, []);

  function onWarningPageDismissed() {
    trackEvent('IdV: Capture troubleshooting dismissed');

    setHasDismissed(true);
  }

  // let FormSteps know, via FormStepsContext, whether this page
  // is ready to submit form values
  useEffect(() => {
    changeStepCanComplete(!!hasDismissed && !skipWarning);
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
