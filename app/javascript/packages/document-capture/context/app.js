import { createContext } from 'react';

/**
 * @typedef AppContext
 *
 * @prop {string} appName name of the application (probably Login.gov)
 */

const AppContext = createContext(/** @type {AppContext} */ ({ appName: '' }));

AppContext.displayName = 'AppContext';

export default AppContext;
