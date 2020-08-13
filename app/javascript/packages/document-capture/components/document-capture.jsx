import React, { useState, useContext } from 'react';
import FormSteps from './form-steps';
import DocumentsStep, { isValid as isDocumentsStepValid } from './documents-step';
import SelfieStep, { isValid as isSelfieStepValid } from './selfie-step';
import MobileIntroStep from './mobile-intro-step';
import DeviceContext from '../context/device';
import Submission from './submission';
import useI18n from '../hooks/use-i18n';

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
  const [formValues, setFormValues] = useState(null);
  const { t } = useI18n();
  const { isMobile } = useContext(DeviceContext);

  const steps = [
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
  ].filter(Boolean);

  return formValues ? (
    <Submission payload={formValues} />
  ) : (
    <FormSteps steps={steps} onComplete={setFormValues} />
  );
}

export default DocumentCapture;
