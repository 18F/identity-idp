import { createContext } from 'react';

export interface FeatureFlagContextProps {
  /**
   * Specify whether to show the not-ready section on doc capture screen.
   * Populated from backend configuration
   */
  notReadySectionEnabled: boolean;
  /**
   * Specify whether to show exit optional questions on doc capture screen.
   */
  exitQuestionSectionEnabled: boolean;
}

const FeatureFlagContext = createContext<FeatureFlagContextProps>({
  notReadySectionEnabled: false,
  exitQuestionSectionEnabled: false,
});

FeatureFlagContext.displayName = 'FeatureFlagContext';

export default FeatureFlagContext;
