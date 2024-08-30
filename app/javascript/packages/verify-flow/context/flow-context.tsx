import { createContext } from 'react';

export interface FlowContextValue {
  /**
   * URL to the path of the account home
   */
  accountURL: string;
  /**
   * URL to path for session cancel.
   */
  cancelURL: string;
  /**
   * Current step name.
   */
  currentStep: string;
}

const FlowContext = createContext<FlowContextValue>({
  accountURL: '',
  cancelURL: '',
  currentStep: '',
});

FlowContext.displayName = 'FlowContext';

export default FlowContext;
