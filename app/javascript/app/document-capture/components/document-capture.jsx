import React, { useState } from 'react';
import AcuantCapture from './acuant-capture';
import DocumentTips from './document-tips';
import Image from './image';
import FormSteps from './form-steps';
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
            name: 'front',
            // Disable reason: This is intended as throwaway code.
            // eslint-disable-next-line react/prop-types
            component: ({ value, onChange }) => (
              // eslint-disable-next-line jsx-a11y/label-has-associated-control
              <label>
                Front
                <input
                  type="text"
                  value={value ?? ''}
                  onChange={(event) => onChange(event.target.value)}
                />
              </label>
            ),
          },
          { name: 'back', component: () => 'Back' },
          { name: 'selfie', component: () => 'Selfie' },
          { name: 'confirm', component: () => 'Confirm?' },
        ]}
        onComplete={setFormValues}
      />
    </>
  );
}

export default DocumentCapture;
