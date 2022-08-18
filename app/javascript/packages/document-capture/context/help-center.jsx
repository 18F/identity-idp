import { createContext } from 'react';
import { addSearchParams } from '@18f/identity-url';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef HelpCenterURLParameters
 *
 * @prop {string} category
 * @prop {string} article
 * @prop {string} location
 */

/**
 * @typedef {(params: HelpCenterURLParameters) => string} GetHelpCenterURL
 */

/**
 * @typedef HelpCenterContext
 *
 * @prop {string} helpCenterRedirectURL
 * @prop {GetHelpCenterURL} getHelpCenterURL
 */

const HelpCenterContext = createContext(
  /** @type {HelpCenterContext} */ ({
    helpCenterRedirectURL: '',
    getHelpCenterURL: (params) => addSearchParams('', params),
  }),
);

HelpCenterContext.displayName = 'HelpCenterContext';

/**
 * @typedef HelpCenterContextProviderProps
 *
 * @prop {Omit<HelpCenterContext, 'getHelpCenterURL'>} value
 * @prop {ReactNode} children
 */

/**
 * @param {HelpCenterContextProviderProps} props
 */
function HelpCenterContextProvider({ value, children }) {
  /** @type {GetHelpCenterURL} */
  const getHelpCenterURL = (params) => addSearchParams(value.helpCenterRedirectURL, params);

  return (
    <HelpCenterContext.Provider value={{ ...value, getHelpCenterURL }}>
      {children}
    </HelpCenterContext.Provider>
  );
}

export default HelpCenterContext;
export { HelpCenterContextProvider as Provider };
