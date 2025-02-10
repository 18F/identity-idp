import { createContext } from 'react';

interface SelfieCaptureProps {
  /**
   * Specify whether to show the selfie capture on the doc capture screen.
   */
  isSelfieCaptureEnabled: boolean;
  /**
   * Specify whether to allow uploads for selfie when in test mode.
   */
  isSelfieDesktopTestMode: boolean;
  /**
   * Specify whether to show help and an action button before showing
   * the capture component.
   */
  showHelpInitially: boolean;
  /**
   * Specify whether we should try to capture using Acuant immediately
   */
  immediatelyBeginCapture: boolean;
}

const SelfieCaptureContext = createContext<SelfieCaptureProps>({
  isSelfieCaptureEnabled: false,
  isSelfieDesktopTestMode: false,
  showHelpInitially: true,
  immediatelyBeginCapture: false,
});

SelfieCaptureContext.displayName = 'SelfieCaptureContext';

export default SelfieCaptureContext;
