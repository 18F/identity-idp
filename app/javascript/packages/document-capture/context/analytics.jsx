import { createContext } from 'react';

/** @typedef {Record<string,string|number|boolean|null>} Payload */

/**
 * @typedef AnalyticsContext
 *
 * @prop {(name:string,payload?:Payload)=>void} addPageAction Log an action with optional payload.
 */

const AnalyticsContext = createContext(
  /** @type {AnalyticsContext} */ ({
    addPageAction: () => {},
  }),
);

export default AnalyticsContext;
