import { useContext } from 'react';
import { FormStepsContext } from '@18f/identity-form-steps';

function useFormChangeCompletion({
  isSelfieCaptureEnabled,
  docAuthSeparatePagesEnabled,
}: {
  isSelfieCaptureEnabled: boolean;
  docAuthSeparatePagesEnabled: boolean;
}) {
  const { changeStepCanComplete } = useContext(FormStepsContext);
  if (isSelfieCaptureEnabled && docAuthSeparatePagesEnabled) {
    changeStepCanComplete(false);
  }
}

export { useFormChangeCompletion };
