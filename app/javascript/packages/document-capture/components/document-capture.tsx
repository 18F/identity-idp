import { useState, useMemo, useContext, useEffect } from 'react';
import { Alert } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import { FormSteps, PromptOnNavigate } from '@18f/identity-form-steps';
import { FlowContext, VerifyFlowStepIndicator, VerifyFlowPath } from '@18f/identity-verify-flow';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import type { FormStep } from '@18f/identity-form-steps';
import { UploadFormEntriesError } from '../services/upload';
import DocumentsStep from './documents-step';
import InPersonPrepareStep from './in-person-prepare-step';
import InPersonLocationStep from './in-person-location-step';
import InPersonSwitchBackStep from './in-person-switch-back-step';
import ReviewIssuesStep from './review-issues-step';
import ServiceProviderContext from '../context/service-provider';
import UploadContext from '../context/upload';
import AnalyticsContext from '../context/analytics';
import Submission from './submission';
import SubmissionStatus from './submission-status';
import { RetrySubmissionError } from './submission-complete';
import { BackgroundEncryptedUploadError } from '../higher-order/with-background-encrypted-upload';
import SuspenseErrorBoundary from './suspense-error-boundary';
import SubmissionInterstitial from './submission-interstitial';
import withProps from '../higher-order/with-props';

/**
 * Returns a new object with specified keys removed.
 *
 * @param object Original object.
 * @param keys Keys to remove.
 *
 * @return Object with keys removed.
 */
export const except = <T extends Record<string, any>>(object: T, ...keys: string[]): Partial<T> =>
  Object.entries(object).reduce((result, [key, value]) => {
    if (!keys.includes(key)) {
      result[key] = value;
    }

    return result;
  }, {});

interface DocumentCaptureProps {
  /**
   * Whether submission should poll for async response.
   */
  isAsyncForm?: boolean;

  /**
   * Callback triggered on step change.
   */
  onStepChange?: () => void;
}

function DocumentCapture({ isAsyncForm = false, onStepChange = () => {} }: DocumentCaptureProps) {
  const [formValues, setFormValues] = useState<Record<string, any> | null>(null);
  const [submissionError, setSubmissionError] = useState<Error | undefined>(undefined);
  const [stepName, setStepName] = useState<string | undefined>(undefined);
  const { t } = useI18n();
  const serviceProvider = useContext(ServiceProviderContext);
  const { flowPath } = useContext(UploadContext);
  const { trackSubmitEvent, trackVisitEvent } = useContext(AnalyticsContext);
  const { inPersonURL } = useContext(FlowContext);
  useDidUpdateEffect(onStepChange, [stepName]);
  useEffect(() => {
    if (stepName) {
      trackVisitEvent(stepName);
    }
  }, [stepName]);

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
        ...(isAsyncForm ? except(formValues, 'front', 'back') : formValues),
        flow_path: flowPath,
      },
    [isAsyncForm, formValues, flowPath],
  );

  let initialActiveErrors;
  if (submissionError instanceof UploadFormEntriesError) {
    initialActiveErrors = submissionError.formEntryErrors.map((error) => ({
      field: error.field,
      error,
    }));
  } else if (submissionError instanceof BackgroundEncryptedUploadError) {
    initialActiveErrors = [{ field: submissionError.baseField, error: submissionError }];
  }

  let initialValues;
  if (submissionError && formValues) {
    initialValues = formValues;

    if (submissionError instanceof BackgroundEncryptedUploadError) {
      initialValues = except(initialValues, ...submissionError.fields);
    }
  }

  const inPersonSteps: FormStep[] =
    inPersonURL === undefined
      ? []
      : ([
          {
            name: 'location',
            form: InPersonLocationStep,
          },
          {
            name: 'prepare',
            form: InPersonPrepareStep,
          },
          flowPath === 'hybrid' && {
            name: 'switch_back',
            form: InPersonSwitchBackStep,
          },
        ].filter(Boolean) as FormStep[]);

  const steps: FormStep[] = submissionError
    ? (
        [
          {
            name: 'review',
            form:
              submissionError instanceof UploadFormEntriesError
                ? withProps({
                    remainingAttempts: submissionError.remainingAttempts,
                    isFailedResult: submissionError.isFailedResult,
                    captureHints: submissionError.hints,
                    pii: submissionError.pii,
                  })(ReviewIssuesStep)
                : ReviewIssuesStep,
          },
        ] as FormStep[]
      ).concat(inPersonSteps)
    : ([
        {
          name: 'documents',
          form: DocumentsStep,
        },
      ].filter(Boolean) as FormStep[]);

  const stepIndicatorPath =
    stepName && ['location', 'prepare', 'switch_back'].includes(stepName)
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
          />
        </>
      )}
    </>
  );
}

export default DocumentCapture;
