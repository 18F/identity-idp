import { createContext } from 'react';

export interface InPersonContextProps {
  /**
   * Feature flag for enabling address search
   */
  arcgisSearchEnabled?: boolean;

  /**
   * Whether or not A/B testing of the in-person proofing CTA is enabled.
   */
  inPersonCtaVariantTestingEnabled?: boolean;

  /**
   * The specific A/B testing variant that was activated for the current user session.
   */
  inPersonCtaVariantActive?: string;

  /**
   * URL to in-person proofing alternative flow, if enabled.
   */
  inPersonURL?: string;
}

const InPersonContext = createContext<InPersonContextProps>({
  arcgisSearchEnabled: false,
  inPersonCtaVariantTestingEnabled: false,
  inPersonCtaVariantActive: '',
});

InPersonContext.displayName = 'InPersonContext';

export default InPersonContext;
