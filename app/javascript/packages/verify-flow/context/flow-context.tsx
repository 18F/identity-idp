import { createContext } from 'react';

export interface FlowContextValue {
  /**
   * URL to path for session cancel.
   */
  cancelURL: string;

  /**
   * URL to exit session without confirmation
   */
  exitURL: string;

  /**
   * Current step name.
   */
  currentStep: string;
}

const FlowContext = createContext<FlowContextValue>({
  cancelURL: '',
  exitURL: '',
  currentStep: '',
});

FlowContext.displayName = 'FlowContext';

export default FlowContext;
