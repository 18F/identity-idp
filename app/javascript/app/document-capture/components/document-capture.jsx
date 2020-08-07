import React, { useState, useContext } from 'react';
import FormSteps from './form-steps';
import DocumentsStep, { isValid as isDocumentsStepValid } from './documents-step';
import SelfieStep, { isValid as isSelfieStepValid } from './selfie-step';
import MobileIntroStep from './mobile-intro-step';
import DeviceContext from '../context/device';
import Submission from './submission';

function DocumentCapture() {
  const [formValues, setFormValues] = useState(null);
  const { isMobile } = useContext(DeviceContext);

  const steps = [
    {
      name: 'documents',
      component: DocumentsStep,
      isValid: isDocumentsStepValid,
    },
    {
      name: 'selfie',
      component: SelfieStep,
      isValid: isSelfieStepValid,
    },
  ];

  if (isMobile) {
    steps.unshift({
      name: 'intro',
      component: MobileIntroStep,
    });
  }

  return formValues ? (
    <Submission payload={formValues} />
  ) : (
    <FormSteps steps={steps} onComplete={setFormValues} />
  );
}

export default DocumentCapture;
