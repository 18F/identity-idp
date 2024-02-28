import { createContext } from 'react';

interface SelfieCaptureEnabledProps {
  /**
   * Specify whether to show the selfie capture on the doc capture screen.
   */
  selfieCaptureEnabled: boolean;
}

const SelfieCaptureEnabledContext = createContext<SelfieCaptureEnabledProps>({
  selfieCaptureEnabled: false,
});

SelfieCaptureEnabledContext.displayName = 'SelfieCaptureEnabledContext';

export default SelfieCaptureEnabledContext;
