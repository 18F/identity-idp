import React, { useState } from 'react';
import AcuantCapture from './acuant-capture';
import FormSteps from './form-steps';
import DocumentsStep, { isValid as isDocumentsStepValid } from './documents-step';
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
          component: AcuantCapture,
        },
        { name: 'confirm', component: () => 'Confirm?' },
      ]}
      onComplete={setFormValues}
    />
  );
}

export default DocumentCapture;
