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
   * Specify whether to seperate seflie upload and document upload into seperate form steps/pages
   */
  docAuthSeparatePagesEnabled: boolean;
}

const SelfieCaptureContext = createContext<SelfieCaptureProps>({
  isSelfieCaptureEnabled: false,
  isSelfieDesktopTestMode: false,
  docAuthSeparatePagesEnabled: false,
});

SelfieCaptureContext.displayName = 'SelfieCaptureContext';

export default SelfieCaptureContext;
