import { createContext } from 'react';

export interface FeatureFlagContextProps {
  /**
   * Specify whether to show the not-ready section on doc capture screen.
   * Populated from backend configuration
   */
  notReadySectionEnabled: boolean;
}

const FeatureFlagContext = createContext<FeatureFlagContextProps>({
  notReadySectionEnabled: false,
});

FeatureFlagContext.displayName = 'FeatureFlagContext';

export default FeatureFlagContext;
