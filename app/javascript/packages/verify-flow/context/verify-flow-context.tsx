import { createContext } from 'react';

interface VerifyFlowContextValue {
  /**
   * The path to which the current step is appended to create the current step URL.
   */
  basePath: string;

  /**
   * URL for reset password page in rails used for redirect
   */
  resetPasswordUrl: string;
}

const VerifyFlowContext = createContext({
  basePath: '',
  resetPasswordUrl: '',
} as VerifyFlowContextValue);

export default VerifyFlowContext;
