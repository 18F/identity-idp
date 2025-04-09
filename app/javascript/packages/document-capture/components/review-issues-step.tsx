import { useContext, useEffect, useLayoutEffect, useState } from 'react';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { FormStepsContext } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import type { PII } from '../services/upload';
import AnalyticsContext from '../context/analytics';
import BarcodeAttentionWarning from './barcode-attention-warning';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';
import SelfieCaptureContext from '../context/selfie-capture';
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
  remainingSubmitAttempts?: number;
  submitAttempts?: number;
  isResultCodeInvalid?: boolean;
  isFailedResult?: boolean;
  isFailedSelfie?: boolean;
  isFailedDocType?: boolean;
  isFailedSelfieLivenessOrQuality?: boolean;
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
  toPreviousStep = () => undefined,
  remainingSubmitAttempts = Infinity,
  submitAttempts,
  isResultCodeInvalid = false,
  isFailedResult = false,
  isFailedDocType = false,
  isFailedSelfie = false,
  isFailedSelfieLivenessOrQuality = false,
  pii,
  failedImageFingerprints = { front: [], back: [] },
}: ReviewIssuesStepProps) {
  const { trackEvent } = useContext(AnalyticsContext);
  const { isSelfieCaptureEnabled } = useContext(SelfieCaptureContext);
  const [hasDismissed, setHasDismissed] = useState(remainingSubmitAttempts === Infinity);
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
    trackEvent('IdV: Capture troubleshooting dismissed', {
      liveness_checking_required: isSelfieCaptureEnabled,
      submit_attempts: submitAttempts,
    });

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
        isResultCodeInvalid={isResultCodeInvalid}
        isFailedDocType={isFailedDocType}
        isFailedResult={isFailedResult}
        isFailedSelfie={isFailedSelfie}
        isFailedSelfieLivenessOrQuality={isFailedSelfieLivenessOrQuality}
        remainingSubmitAttempts={remainingSubmitAttempts}
        unknownFieldErrors={unknownFieldErrors}
        actionOnClick={onWarningPageDismissed}
        hasDismissed={false}
      />
    );
  }
  // Show review issue screen, hasDismissed = true
  return (
    <DocumentCaptureReviewIssues
      isFailedSelfie={isFailedSelfie}
      isFailedDocType={isFailedDocType}
      isFailedSelfieLivenessOrQuality={isFailedSelfieLivenessOrQuality}
      remainingSubmitAttempts={remainingSubmitAttempts}
      value={value}
      unknownFieldErrors={unknownFieldErrors}
      registerField={registerField}
      errors={errors}
      onChange={onChange}
      onError={onError}
      toPreviousStep={toPreviousStep}
      hasDismissed
    />
  );
}

export default ReviewIssuesStep;
