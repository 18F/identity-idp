import { createContext } from 'react';

export interface FeatureFlagContextProps {
  /**
   * Specify whether to show exit optional questions on doc capture screen.
   */
  exitQuestionSectionEnabled: boolean;
}

const FeatureFlagContext = createContext<FeatureFlagContextProps>({
  exitQuestionSectionEnabled: false,
});

FeatureFlagContext.displayName = 'FeatureFlagContext';

export default FeatureFlagContext;
