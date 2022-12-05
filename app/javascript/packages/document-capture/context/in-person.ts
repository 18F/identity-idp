import { createContext } from 'react';

export interface InPersonContextProps {
  /**
   * Feature flag for enabling address search
   */
  arcgisSearchEnabled?: boolean;

  /**
   * URL to in-person proofing alternative flow, if enabled.
   */
  inPersonURL?: string;
}

const InPersonContext = createContext<InPersonContextProps>({
  arcgisSearchEnabled: false,
});

InPersonContext.displayName = 'InPersonContext';

export default InPersonContext;
