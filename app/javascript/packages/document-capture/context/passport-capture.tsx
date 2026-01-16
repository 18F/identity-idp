import { createContext } from 'react';

interface PassportCaptureProps {
  /**
   * Specify whether to show help and an action button before showing
   * the capture component.
   */
  showHelpInitially: boolean;
}

const PassportCaptureContext = createContext<PassportCaptureProps>({
  showHelpInitially: true,
});

PassportCaptureContext.displayName = 'PassportCaptureContext';

export default PassportCaptureContext;
