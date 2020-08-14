import React, { useState, useContext } from 'react';
import { Alert } from '@18f/identity-components';
import FormSteps from './form-steps';
import DocumentsStep, { isValid as isDocumentsStepValid } from './documents-step';
import SelfieStep, { isValid as isSelfieStepValid } from './selfie-step';
import MobileIntroStep from './mobile-intro-step';
import DeviceContext from '../context/device';
import Submission from './submission';
import useI18n from '../hooks/use-i18n';

/** @typedef {import('./form-steps').FormStep} FormStep */

/**
 * @typedef DocumentCaptureProps
 *
 * @prop {boolean=} isLivenessEnabled Whether liveness capture should be expected from the user.
 *                                    Defaults to false.
 */

/**
 * @param {DocumentCaptureProps} props Props object.
 */
function DocumentCapture({ isLivenessEnabled = true }) {
  const [formValues, setFormValues] = useState(/** @type {Record<string,any>?} */ (null));
  const [isSubmissionError, setIsSubmissionError] = useState(false);
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
      isValid: isDocumentsStepValid,
    },
    isLivenessEnabled && {
      name: 'selfie',
      title: t('doc_auth.headings.selfie'),
      component: SelfieStep,
      isValid: isSelfieStepValid,
    },
  ].filter(Boolean));

  /**
   * Clears error state and sets form values for submission.
   *
   * @param {Record<string,any>} nextFormValues Submitted form values.
   */
  function submitForm(nextFormValues) {
    setIsSubmissionError(false);
    setFormValues(nextFormValues);
  }

  return formValues && !isSubmissionError ? (
    <Submission payload={formValues} onError={() => setIsSubmissionError(true)} />
  ) : (
    <>
      {isSubmissionError && <Alert type="error">{t('errors.doc_auth.acuant_network_error')}</Alert>}
      <FormSteps steps={steps} initialValues={formValues ?? undefined} onComplete={submitForm} />
    </>
  );
}

export default DocumentCapture;
