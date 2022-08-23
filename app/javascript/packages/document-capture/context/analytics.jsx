import { createContext } from 'react';

/** @typedef {import('@18f/identity-analytics').trackEvent} TrackEvent */
/** @typedef {Record<string,string|number|boolean|null|undefined>} Payload */

/**
 * @typedef PageAction
 *
 * @property {string=} key Short, camel-cased, dot-namespaced key describing event.
 * @property {string} label Long-form, human-readable label describing event action.
 * @property {Payload=} payload Additional payload arguments to log with action.
 */

/**
 * @typedef AnalyticsContext
 *
 * @prop {TrackEvent} trackEvent Log an action with optional payload.
 */

const AnalyticsContext = createContext(
  /** @type {AnalyticsContext} */ ({
    trackEvent: () => Promise.resolve(),
  }),
);

AnalyticsContext.displayName = 'AnalyticsContext';

export default AnalyticsContext;
