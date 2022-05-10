import { createContext } from 'react';

interface FormStepsContextValue {
  /**
   * Whether the current step is the last step in the flow.
   */
  isLastStep: boolean;

  /**
   * Whether the current step is pending submission.
   */
  isSubmitting: boolean;

  /**
   * URL for reset password page in rails used for redirect
   */
  resetPasswordUrl?: string;

  /**
   * Callback invoked when content is reset in a page transition.
   */
  onPageTransition: () => void;
}

const FormStepsContext = createContext({
  isLastStep: true,
  isSubmitting: false,
  onPageTransition: () => {},
  resetPasswordUrl: '',
} as FormStepsContextValue);

export default FormStepsContext;
