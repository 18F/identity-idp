import { createContext } from 'react';

export interface InPersonContextProps {
  /**
   * URL to in-person proofing alternative flow, if enabled.
   */
  inPersonURL?: string;

  /**
   * Whether the message indicating a USPS outage should be displayed
   */
  inPersonUspsOutageMessageEnabled: boolean;
}

const InPersonContext = createContext<InPersonContextProps>({
  inPersonUspsOutageMessageEnabled: false,
});

InPersonContext.displayName = 'InPersonContext';

export default InPersonContext;
