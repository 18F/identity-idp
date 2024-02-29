import { createContext } from 'react';

interface SelfieCaptureEnabledProps {
  /**
   * Specify whether to show the selfie capture on the doc capture screen.
   */
  selfieCaptureEnabled: boolean;
}

const SelfieCaptureContext = createContext<SelfieCaptureEnabledProps>({
  selfieCaptureEnabled: false,
});

SelfieCaptureContext.displayName = 'SelfieCaptureContext';

export default SelfieCaptureContext;
