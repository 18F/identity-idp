import type { noticeError } from 'newrelic';

type NewRelicAgent = { noticeError: typeof noticeError };

interface NewRelicGlobals {
  newrelic?: NewRelicAgent;
}

/**
 * Logs an error.
 *
 * @param error Error object.
 */
function trackError(error: Error) {
  (globalThis as typeof globalThis & NewRelicGlobals).newrelic?.noticeError(error);
}

export default trackError;
