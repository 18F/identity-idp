import { createContext } from 'react';

/** @typedef {Record<string,string|number|boolean|null|undefined>} Payload */

/**
 * @typedef PageAction
 *
 * @property {string=} key Short, camel-cased, dot-namespaced key describing event.
 * @property {string} label Long-form, human-readable label describing event action.
 * @property {Payload=} payload Additional payload arguments to log with action.
 */

/**
 * @typedef {(action: PageAction)=>void} AddPageAction
 */

/**
 * @typedef {(error: Error)=>void} NoticeError
 */

/**
 * @typedef AnalyticsContext
 *
 * @prop {AddPageAction} addPageAction Log an action with optional payload.
 * @prop {NoticeError} noticeError Log an error without affecting application behavior.
 */

const AnalyticsContext = createContext(
  /** @type {AnalyticsContext} */ ({
    addPageAction: () => {},
    noticeError: () => {},
  }),
);

AnalyticsContext.displayName = 'AnalyticsContext';

export default AnalyticsContext;
