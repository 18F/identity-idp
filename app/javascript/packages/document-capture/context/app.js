import { createContext } from 'react';

/**
 * @typedef AppContext
 *
 * @prop {string} appName name of the application (probably Login.gov)
 * @prop {string} arcgisSearchEnabled feature flag for enabling address search
 */

const AppContext = createContext(
  /** @type {AppContext} */ ({ appName: '', arcgisSearchEnabled: 'false' }),
);

AppContext.displayName = 'AppContext';

export default AppContext;
