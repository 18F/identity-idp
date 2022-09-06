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

  /**
   * The path to which the current step is appended to create the current step URL.
   */
  basePath: string;

  /**
   * Handle flow completion with a given destination URL.
   */
  onComplete: ({ completionURL }: { completionURL: string }) => void;
}

const FlowContext = createContext<FlowContextValue>({
  cancelURL: '',
  currentStep: '',
  basePath: '',
  onComplete() {},
});

FlowContext.displayName = 'FlowContext';

export default FlowContext;
