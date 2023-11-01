import { createContext } from 'react';

export interface UIConfigContextProps {
  /**
   * Specify whether to show the not-ready section on doc capture screen.
   * Populated from backend configuration
   */
  notReadySectionEnabled: boolean;
}

const UIConfigContext = createContext<UIConfigContextProps>({
  notReadySectionEnabled: false,
});

UIConfigContext.displayName = 'UIConfigContext';

export default UIConfigContext;
