import { createContext } from 'react';

/**
 * @typedef AppContext
 *
 * @prop {string} appName name of the application (probably Login.gov)
 */

type AppContextType = {
  appName: string;
};

const AppContext = createContext<AppContextType>({ appName: '' });

AppContext.displayName = 'AppContext';

export default AppContext;
