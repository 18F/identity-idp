import { createContext } from 'react';

/**
 * @typedef AnalyticsContext
 *
 * @prop {(name:string,payload?:object)=>void} addPageAction Log an action with optional payload.
 */

const AnalyticsContext = createContext(
  /** @type {AnalyticsContext} */ ({
    addPageAction: () => {},
  }),
);

export default AnalyticsContext;
