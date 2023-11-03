import { createContext } from 'react';

/**
 * This file should contain any context that exists only to make a single
 * display variable from the BE IdentityConfig available to the FE. We're doing
 * it this way to:
 * - Try and avoid 'ui-config' turning into a collection of miscellaneous values
 * that's hard to untangle
 * - Try and make these single purpose contexts easier to read.
 */
interface NotReadySectionUIContextProps {
  /**
   * Specify whether to show the not-ready section on doc capture screen.
   * Populated from backend configuration
   */
  notReadySectionEnabled: boolean;
}
export const NotReadySectionUIContext = createContext<NotReadySectionUIContextProps>({
  notReadySectionEnabled: false,
});
NotReadySectionUIContext.displayName = 'NotReadySectionUIContext';

interface SomeOtherUIContextProps {
  someOtherUIContextBoolean: boolean;
}
export const SomeOtherUIContext = createContext<SomeOtherUIContextProps>({
  someOtherUIContextBoolean: false,
});
SomeOtherUIContext.displayName = 'SomeOtherUIContext';
