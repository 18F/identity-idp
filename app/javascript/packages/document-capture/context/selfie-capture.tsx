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
   * Specify whether we're currently showing help and an action button
   */
  showHelp: boolean;
}

const SelfieCaptureContext = createContext<SelfieCaptureProps>({
  isSelfieCaptureEnabled: false,
  isSelfieDesktopTestMode: false,
  showHelpInitially: false,
  showHelp: false,
});

SelfieCaptureContext.displayName = 'SelfieCaptureContext';

export default SelfieCaptureContext;
