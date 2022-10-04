import { createContext } from 'react';

export interface FlowContextValue {
  /**
   * URL to path for session cancel.
   */
  cancelURL: string;

  /**
   * URL to in-person proofing alternative flow, if enabled.
   */
  inPersonURL?: string;

  /**
   * Current step name.
   */
  currentStep: string;
}

const FlowContext = createContext<FlowContextValue>({
  cancelURL: '',
  currentStep: '',
});

FlowContext.displayName = 'FlowContext';

export default FlowContext;
