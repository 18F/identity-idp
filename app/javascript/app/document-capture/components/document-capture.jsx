import React, { useState } from 'react';
import AcuantCapture from './acuant-capture';
import DocumentTips from './document-tips';
import Image from './image';
import FormSteps from './form-steps';
import DocumentsStep from './documents-step';
import Submission from './submission';

function DocumentCapture() {
  const [formValues, setFormValues] = useState(null);

  const sample = (
    <Image
      assetPath="state-id-sample-front.jpg"
      alt="Sample front of state issued ID"
      width={450}
      height={338}
    />
  );

  return formValues ? (
    <Submission payload={formValues} />
  ) : (
    <>
      <AcuantCapture />
      <DocumentTips sample={sample} />
      <FormSteps
        steps={[
          {
            name: 'documents',
            component: DocumentsStep,
          },
          { name: 'selfie', component: () => 'Selfie' },
          { name: 'confirm', component: () => 'Confirm?' },
        ]}
        onComplete={setFormValues}
      />
    </>
  );
}

export default DocumentCapture;
