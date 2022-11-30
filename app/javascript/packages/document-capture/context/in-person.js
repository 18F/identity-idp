import { createContext } from 'react';

/**
 * @typedef InPersonContext
 *
 * @prop {boolean} arcgisSearchEnabled feature flag for enabling address search
 */

const InPersonContext = createContext(
  /** @type {InPersonContext} */ ({ arcgisSearchEnabled: false }),
);

InPersonContext.displayName = 'InPersonContext';

export default InPersonContext;
