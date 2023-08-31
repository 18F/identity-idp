import { createContext } from 'react';

export interface InPersonContextProps {
  /**
   * URL to in-person proofing alternative flow, if enabled.
   */
  inPersonURL?: string;

  /**
   * Whether the message indicating an outage should be displayed
   */
  inPersonOutageMessageEnabled: boolean;

  /**
   * Date communicated to users regarding expected update about their enrollment after an outage
   */
  inPersonOutageExpectedUpdateDate?: string;
}

const InPersonContext = createContext<InPersonContextProps>({
  inPersonOutageMessageEnabled: false,
});

InPersonContext.displayName = 'InPersonContext';

export default InPersonContext;
