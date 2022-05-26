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

  /**
   * The path to which the current step is appended to create the current step URL.
   */
  basePath: '',
});

FlowContext.displayName = 'FlowContext';

export default FlowContext;
