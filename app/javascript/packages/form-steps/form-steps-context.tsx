import { createContext } from 'react';

interface FormStepsContextValue {
  /**
   * Allow FormSteps to tell the current step that it is the
   * last step in the flow.
   */
  isLastStep: boolean;

  /**
   * Allow a step to tell FormSteps it can complete the flow
   */
  changeStepCanComplete: (isComplete: boolean) => void;

  /**
   * Whether the current step is pending submission.
   */
  isSubmitting: boolean;

  /**
   * Callback invoked when content is reset in a page transition.
   */
  onPageTransition: () => void;
}

const FormStepsContext = createContext({
  isLastStep: true,
  changeStepCanComplete: () => {},
  isSubmitting: false,
  onPageTransition: () => {},
} as FormStepsContextValue);

export default FormStepsContext;
