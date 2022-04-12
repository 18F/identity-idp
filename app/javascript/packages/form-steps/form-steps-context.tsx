import { createContext } from 'react';

interface FormStepsContextValue {
  /**
   * Whether the current step is the last step in the flow.
   */
  isLastStep: boolean;

  /**
   * Whether the user can proceed to the next step.
   */
  canContinueToNextStep: boolean;

  /**
   * Callback invoked when content is reset in a page transition.
   */
  onPageTransition: () => void;
}

const FormStepsContext = createContext({
  isLastStep: true,
  canContinueToNextStep: true,
  onPageTransition: () => {},
} as FormStepsContextValue);

export default FormStepsContext;
