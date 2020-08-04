import React, { useState } from 'react';
import FormSteps from './form-steps';
import DocumentsStep, { isValid as isDocumentsStepValid } from './documents-step';
import SelfieStep, { isValid as isSelfieStepValid } from './selfie-step';
import Submission from './submission';

function DocumentCapture() {
  const [formValues, setFormValues] = useState(null);

  return formValues ? (
    <Submission payload={formValues} />
  ) : (
    <FormSteps
      steps={[
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
      ]}
      onComplete={setFormValues}
    />
  );
}

export default DocumentCapture;
