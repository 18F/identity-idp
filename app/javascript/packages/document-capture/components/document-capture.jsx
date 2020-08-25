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

/**
 * @typedef DocumentCaptureProps
 *
 * @prop {boolean=} isLivenessEnabled Whether liveness capture should be expected from the user.
 *                                    Defaults to false.
 */

/**
 * Returns error messages interspersed with line break React element.
 *
 * @param {string[]} errors Error messages.
 *
 * @return {ReactNode[]} Formatted error messages.
 */
export function getFormattedErrors(errors) {
  return errors.flatMap((error, i) => [<br key={i} />, error]).slice(1);
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
    },
    isLivenessEnabled && {
      name: 'selfie',
      title: t('doc_auth.headings.selfie'),
      component: SelfieStep,
      validate: validateSelfieStep,
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

  const isFormEntriesError = submissionError && submissionError instanceof UploadFormEntriesError;
  let initialStep;
  if (submissionError) {
    initialStep = isFormEntriesError || !isLivenessEnabled ? 'documents' : 'selfie';
  }

  return formValues && !submissionError ? (
    <Submission
      payload={formValues}
      onError={(nextSubmissionError) => setSubmissionError(nextSubmissionError)}
    />
  ) : (
    <>
      {submissionError && (
        <Alert type="error" className="margin-bottom-2">
          {isFormEntriesError
            ? getFormattedErrors(/** @type {UploadFormEntriesError} */ (submissionError).rawErrors)
            : t('errors.doc_auth.acuant_network_error')}
        </Alert>
      )}
      <FormSteps
        steps={steps}
        initialValues={submissionError && formValues ? formValues : undefined}
        initialStep={initialStep}
        onComplete={submitForm}
      />
    </>
  );
}

export default DocumentCapture;
