import { createContext } from 'react';

interface SelfieCaptureProps {
  /**
   * Specify whether to show the selfie capture on the doc capture screen.
   */
  isSelfieCaptureEnabled: boolean;
  /**
   * Specify whether to allow uploads for selfie when in test mode.
   */
  isSelfieDesktopMode: boolean;
}

const SelfieCaptureContext = createContext<SelfieCaptureProps>({
  isSelfieCaptureEnabled: false,
  isSelfieDesktopMode: false,
});

SelfieCaptureContext.displayName = 'SelfieCaptureContext';

export default SelfieCaptureContext;
