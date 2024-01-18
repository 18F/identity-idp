import { createContext } from 'react';

export interface FeatureFlagContextProps {
  /**
   * Specify whether to show exit optional questions on doc capture screen.
   */
  exitQuestionSectionEnabled: boolean;
  /**
   * Specify whether to show the selfie capture on the doc capture screen.
   */
  selfieCaptureEnabled: boolean;
}

const FeatureFlagContext = createContext<FeatureFlagContextProps>({
  exitQuestionSectionEnabled: false,
  selfieCaptureEnabled: false,
});

FeatureFlagContext.displayName = 'FeatureFlagContext';

export default FeatureFlagContext;
