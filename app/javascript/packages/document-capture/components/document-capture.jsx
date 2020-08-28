import React, { useState, useContext } from 'react';
import { Alert } from '@18f/identity-components';
import FormSteps from './form-steps';
import { UploadFormEntriesError } from '../services/upload';
import DocumentsStep, { validate as validateDocumentsStep } from './documents-step';
import SelfieStep, { validate as validateSelfieStep } from './selfie-step';
import MobileIntroStep from './mobile-intro-step';
import DeviceContext from '../context/device';
import Submission from './submission';
import useI18n from '../hooks/use-i18n';

/** @typedef {import('react').ReactNode} ReactNode */
/** @typedef {import('./form-steps').FormStep} FormStep */
/** @typedef {import('../context/upload').UploadFieldError} UploadFieldError */
/** @typedef {import('./form-steps').FormStepError<Record<string,any>>} FormStepError */

/**
 * @typedef DocumentCaptureProps
 *
 * @prop {boolean=} isLivenessEnabled Whether liveness capture should be expected from the user.
 *                                    Defaults to false.
 */

/**
 * Returns the first step name associated with an array of errors, or undefined if there are no
 * errors or the step cannot be determined.
 *
 * @param {FormStep[]} steps Form steps.
 * @param {FormStepError[]} errors Form errors.
 *
 * @return {string=} Initial step name, if known.
 */
export function getInitialStep(steps, errors) {
  return steps.find((step) => {
    const stepHasError = step.fields?.some((field) => {
      const fieldHasError = errors.some((error) => error.field === field);
      return fieldHasError;
    });

    return stepHasError;
  })?.name;
}

/**
 * @param {DocumentCaptureProps} props Props object.
 */
function DocumentCapture({ isLivenessEnabled = true }) {
  const [formValues, setFormValues] = useState(/** @type {Record<string,any>?} */ (null));
  const [submissionError, setSubmissionError] = useState(/** @type {Error?} */ (null));
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);

  const steps = /** @type {FormStep[]} */ ([
    isMobile && {
      name: 'intro',
      title: t('doc_auth.headings.document_capture'),
      component: MobileIntroStep,
    },
    {
      name: 'documents',
      title: t('doc_auth.headings.document_capture'),
      component: DocumentsStep,
      validate: validateDocumentsStep,
      fields: ['front', 'back'],
    },
    isLivenessEnabled && {
      name: 'selfie',
      title: t('doc_auth.headings.selfie'),
      component: SelfieStep,
      validate: validateSelfieStep,
      fields: ['selfie'],
    },
  ].filter(Boolean));

  /**
   * Clears error state and sets form values for submission.
   *
   * @param {Record<string,any>} nextFormValues Submitted form values.
   */
  function submitForm(nextFormValues) {
    setSubmissionError(null);
    setFormValues(nextFormValues);
  }

  /** @type {string=} */
  let initialStep;

  /** @type {FormStepError[]=} */
  let initialActiveErrors;

  /** @type {boolean} */
  let isUnknownError = false;

  if (submissionError) {
    if (submissionError instanceof UploadFormEntriesError) {
      initialActiveErrors = submissionError.rawErrors.map((error) => ({
        field: error.field,
        error,
      }));

      initialStep = getInitialStep(steps, initialActiveErrors);
    } else {
      isUnknownError = true;
      initialStep = steps[steps.length - 1].name;
    }
  }

  return formValues && !submissionError ? (
    <Submission
      payload={formValues}
      onError={(nextSubmissionError) => setSubmissionError(nextSubmissionError)}
    />
  ) : (
    <>
      {isUnknownError && (
        <Alert type="error" className="margin-bottom-2">
          {t('errors.doc_auth.acuant_network_error')}
        </Alert>
      )}
      <FormSteps
        steps={steps}
        initialValues={submissionError && formValues ? formValues : undefined}
        initialActiveErrors={initialActiveErrors}
        initialStep={initialStep}
        onComplete={submitForm}
      />
    </>
  );
}

export default DocumentCapture;
