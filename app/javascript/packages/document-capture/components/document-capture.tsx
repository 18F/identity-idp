import { useState, useMemo, useContext, useEffect } from 'react';
import { Alert } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import { FormSteps, PromptOnNavigate } from '@18f/identity-form-steps';
import { VerifyFlowStepIndicator, VerifyFlowPath } from '@18f/identity-verify-flow';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { getConfigValue } from '@18f/identity-config';
import { UploadFormEntriesError } from '../services/upload';
import UploadContext from '../context/upload';
import AnalyticsContext from '../context/analytics';
import Submission from './submission';
import SubmissionStatus from './submission-status';
import { RetrySubmissionError } from './submission-complete';
import SuspenseErrorBoundary from './suspense-error-boundary';
import SubmissionInterstitial from './submission-interstitial';
import { useSteps } from '../hooks/useSteps';

interface DocumentCaptureProps {
  /**
   * Callback triggered on step change.
   */
  onStepChange?: () => void;
}

function DocumentCapture({ onStepChange = () => {} }: DocumentCaptureProps) {
  const [formValues, setFormValues] = useState<Record<string, any> | null>(null);
  const [submissionError, setSubmissionError] = useState<Error | undefined>(undefined);
  const [stepName, setStepName] = useState<string | undefined>(undefined);
  const { t } = useI18n();
  const { flowPath } = useContext(UploadContext);
  const { trackSubmitEvent, trackVisitEvent } = useContext(AnalyticsContext);
  const appName = getConfigValue('appName');

  useDidUpdateEffect(onStepChange, [stepName]);
  useEffect(() => {
    if (stepName) {
      trackVisitEvent(stepName);
    }
  }, [stepName]);
  const steps = useSteps(submissionError);

  /**
   * Clears error state and sets form values for submission.
   *
   * @param nextFormValues Submitted form values.
   */
  function submitForm(nextFormValues: Record<string, any>) {
    setSubmissionError(undefined);
    setFormValues(nextFormValues);
  }

  const submissionFormValues = useMemo(
    () =>
      formValues && {
        ...formValues,
        flow_path: flowPath,
      },
    [formValues, flowPath],
  );

  let initialActiveErrors;
  if (submissionError instanceof UploadFormEntriesError) {
    initialActiveErrors = submissionError.formEntryErrors.map((error) => ({
      field: error.field,
      error,
    }));
  }

  let initialValues;
  if (submissionError && formValues) {
    initialValues = formValues;
  }

  const inPersonProofingStepNames = ['location', 'prepare', 'switch_back'];
  const stepIndicatorPath =
    stepName && inPersonProofingStepNames.includes(stepName)
      ? VerifyFlowPath.IN_PERSON
      : VerifyFlowPath.DEFAULT;

  return (
    <>
      <VerifyFlowStepIndicator currentStep="document_capture" path={stepIndicatorPath} />
      {submissionFormValues &&
      (!submissionError || submissionError instanceof RetrySubmissionError) ? (
        <>
          <SubmissionInterstitial autoFocus />
          <SuspenseErrorBoundary
            fallback={<PromptOnNavigate />}
            onError={setSubmissionError}
            handledError={submissionError}
          >
            {submissionError instanceof RetrySubmissionError ? (
              <SubmissionStatus />
            ) : (
              <Submission payload={submissionFormValues} />
            )}
          </SuspenseErrorBoundary>
        </>
      ) : (
        <>
          {submissionError && !(submissionError instanceof UploadFormEntriesError) && (
            <Alert type="error" className="margin-bottom-4">
              {t('doc_auth.errors.general.network_error')}
            </Alert>
          )}
          <FormSteps
            steps={steps}
            initialValues={initialValues}
            initialActiveErrors={initialActiveErrors}
            onComplete={submitForm}
            onStepChange={setStepName}
            onStepSubmit={trackSubmitEvent}
            autoFocus={!!submissionError}
            titleFormat={`%{step} - ${appName}`}
          />
        </>
      )}
    </>
  );
}

export default DocumentCapture;
