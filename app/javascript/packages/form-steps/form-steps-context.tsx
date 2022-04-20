import { createContext } from 'react';

interface FormStepsContextValue {
  /**
   * Whether the current step is the last step in the flow.
   */
  isLastStep: boolean;

  /**
   * Validate form and continue to next step if valid.
   */
  toNextStep: () => void;

  /**
   * Callback invoked when content is reset in a page transition.
   */
  onPageTransition: () => void;
}

export const DEFAULT_CONTEXT: FormStepsContextValue = {
  isLastStep: true,
  toNextStep() {},
  onPageTransition() {},
};

const FormStepsContext = createContext(DEFAULT_CONTEXT);

export default FormStepsContext;
