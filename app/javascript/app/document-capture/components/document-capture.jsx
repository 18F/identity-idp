import React, { useState } from 'react';
import AcuantCapture from './acuant-capture';
import FormSteps from './form-steps';
import DocumentsStep, { isValid as isDocumentsStepValid } from './documents-step';
import Submission from './submission';
import DocumentsIntro from './documents-intro';
import useDeviceHasVideoFacingMode from '../hooks/use-device-has-video-facing-mode';

function DocumentCapture() {
  const [formValues, setFormValues] = useState(null);
  const isEnvironmentCaptureDevice = useDeviceHasVideoFacingMode('environment');

  const steps = [
    {
      name: 'documents',
      component: DocumentsStep,
      isValid: isDocumentsStepValid,
    },
    {
      name: 'selfie',
      component: AcuantCapture,
    },
    { name: 'confirm', component: () => 'Confirm?' },
  ];

  if (isEnvironmentCaptureDevice) {
    steps.unshift({
      name: 'intro',
      component: DocumentsIntro,
    });
  }

  return formValues ? (
    <Submission payload={formValues} />
  ) : (
    <FormSteps steps={steps} onComplete={setFormValues} />
  );
}

export default DocumentCapture;
