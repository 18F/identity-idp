import { createContext } from 'react';

const FlowContext = createContext({
  /**
   * URL to path for session restart.
   */
  startOverURL: '',

  /**
   * URL to path for session cancel.
   */
  cancelURL: '',

  /**
   * Current step name.
   */
  currentStep: '',
});

FlowContext.displayName = 'FlowContext';

export default FlowContext;
