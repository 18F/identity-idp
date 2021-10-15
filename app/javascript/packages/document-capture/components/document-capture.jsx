import { useState, useMemo, useContext } from 'react';
import { Alert } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import FormSteps from './form-steps';
import { UploadFormEntriesError } from '../services/upload';
import DocumentsStep, { documentsStepValidator } from './documents-step';
import SelfieStep, { selfieStepValidator } from './selfie-step';
import ReviewIssuesStep, { reviewIssuesStepValidator } from './review-issues-step';
import ServiceProviderContext from '../context/service-provider';
import Submission from './submission';
import SubmissionStatus from './submission-status';
import DesktopDocumentDisclosure from './desktop-document-disclosure';
import { RetrySubmissionError } from './submission-complete';
import { BackgroundEncryptedUploadError } from '../higher-order/with-background-encrypted-upload';
import SuspenseErrorBoundary from './suspense-error-boundary';
import SubmissionInterstitial from './submission-interstitial';
import PromptOnNavigate from './prompt-on-navigate';

/** @typedef {import('react').ReactNode} ReactNode */
/** @typedef {import('./form-steps').FormStep} FormStep */
/** @typedef {import('../context/upload').UploadFieldError} UploadFieldError */

/**
 * Returns a new object with specified keys removed.
 *
 * @template {Record<string,any>} T
 *
 * @param {T} object Original object.
 * @param {...string} keys Keys to remove.
 *
 * @return {Partial<T>} Object with keys removed.
 */
export const except = (object, ...keys) =>
  Object.entries(object).reduce((result, [key, value]) => {
    if (!keys.includes(key)) {
      result[key] = value;
    }

    return result;
  }, {});

/**
 * @typedef DocumentCaptureProps
 *
 * @prop {boolean=} isAsyncForm Whether submission should poll for async response.
 * @prop {()=>void=} onStepChange Callback triggered on step change.
 */

/**
 * @param {DocumentCaptureProps} props
 */
function DocumentCapture({ isAsyncForm = false, onStepChange }) {
  const [formValues, setFormValues] = useState(/** @type {Record<string,any>?} */ (null));
  const [submissionError, setSubmissionError] = useState(/** @type {Error=} */ (undefined));
  const { t } = useI18n();
  const serviceProvider = useContext(ServiceProviderContext);

  /**
   * Clears error state and sets form values for submission.
   *
   * @param {Record<string,any>} nextFormValues Submitted form values.
   */
  function submitForm(nextFormValues) {
    setSubmissionError(undefined);
    setFormValues(nextFormValues);
  }

  const submissionFormValues = useMemo(
    () => (formValues && isAsyncForm ? except(formValues, 'front', 'back', 'selfie') : formValues),
    [isAsyncForm, formValues],
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

  /** @type {FormStep[]} */
  const steps = submissionError
    ? [
        {
          name: 'review',
          title: t('doc_auth.headings.review_issues'),
          form: ReviewIssuesStep,
          validator: reviewIssuesStepValidator,
          footer: DesktopDocumentDisclosure,
        },
      ]
    : /** @type {FormStep[]} */ ([
        {
          name: 'documents',
          title: t('doc_auth.headings.document_capture'),
          form: DocumentsStep,
          validator: documentsStepValidator,
          footer: DesktopDocumentDisclosure,
        },
        serviceProvider.isLivenessRequired && {
          name: 'selfie',
          title: t('doc_auth.headings.selfie'),
          form: SelfieStep,
          validator: selfieStepValidator,
        },
      ].filter(Boolean));

  return submissionFormValues &&
    (!submissionError || submissionError instanceof RetrySubmissionError) ? (
    <SuspenseErrorBoundary
      fallback={
        <>
          <PromptOnNavigate />
          <SubmissionInterstitial autoFocus />
        </>
      }
      onError={setSubmissionError}
      handledError={submissionError}
    >
      {submissionError instanceof RetrySubmissionError ? (
        <SubmissionStatus />
      ) : (
        <Submission payload={submissionFormValues} />
      )}
    </SuspenseErrorBoundary>
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
        onStepChange={onStepChange}
        autoFocus={!!submissionError}
      />
    </>
  );
}

export default DocumentCapture;
