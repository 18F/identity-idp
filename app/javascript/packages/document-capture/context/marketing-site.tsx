import { createContext, useCallback } from 'react';
import type { ReactNode } from 'react';
import { addSearchParams } from '@18f/identity-url';
import { useObjectMemo } from '@18f/identity-react-hooks';

interface HelpCenterURLParameters {
  category: string;

  article: string;

  location: string;
}

type GetHelpCenterURL = (params: HelpCenterURLParameters) => string;

interface MarketingSiteContextValue {
  getHelpCenterURL: GetHelpCenterURL;

  securityAndPrivacyHowItWorksURL?: string;
}

interface MarketingSiteContextProviderProps {
  helpCenterRedirectURL: string;

  securityAndPrivacyHowItWorksURL?: string;

  children: ReactNode;
}

const MarketingSiteContext = createContext({
  getHelpCenterURL: (params) => addSearchParams('', params),
} as MarketingSiteContextValue);

MarketingSiteContext.displayName = 'MarketingSiteContext';

function MarketingSiteContextProvider({
  helpCenterRedirectURL,
  securityAndPrivacyHowItWorksURL,
  children,
}: MarketingSiteContextProviderProps) {
  const getHelpCenterURL: GetHelpCenterURL = useCallback(
    (params) => addSearchParams(helpCenterRedirectURL, params),
    [helpCenterRedirectURL],
  );
  const value = useObjectMemo({ getHelpCenterURL, securityAndPrivacyHowItWorksURL });

  return <MarketingSiteContext.Provider value={value}>{children}</MarketingSiteContext.Provider>;
}

export default MarketingSiteContext;
export { MarketingSiteContextProvider as Provider };
