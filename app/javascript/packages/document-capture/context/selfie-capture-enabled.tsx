import { createContext } from 'react';

interface SelfieCaptureEnabledProps {
  /**
   * Specify whether to show the selfie capture on the doc capture screen.
   */
  isSelfieCaptureEnabled: boolean;
}

const SelfieCaptureContext = createContext<SelfieCaptureEnabledProps>({
  isSelfieCaptureEnabled: false,
});

SelfieCaptureContext.displayName = 'SelfieCaptureContext';

export default SelfieCaptureContext;
