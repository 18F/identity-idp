import type { noticeError } from 'newrelic';
import { getConfigValue } from '@18f/identity-config';

type NewRelicAgent = { noticeError: typeof noticeError };

interface NewRelicGlobals {
  newrelic?: NewRelicAgent;
}

/**
 * Logs an event.
 *
 * @param event Event name.
 * @param payload Payload object.
 */
export function trackEvent(event: string, payload?: object) {
  const endpoint = getConfigValue('analyticsEndpoint');

  // Make analytics requests using sendBeacon(), which can be prioritized appropriately by the
  // browser and have a better chance of succeeding during page unload than fetch().
  if (endpoint && navigator.sendBeacon) {
    const eventJson = JSON.stringify({ event, payload });
    const blob = new Blob([eventJson], { type: 'application/json' });
    navigator.sendBeacon(endpoint, blob);
  }
}

/**
 * Logs an error.
 *
 * @param error Error object.
 */
export function trackError(error: Error) {
  (globalThis as typeof globalThis & NewRelicGlobals).newrelic?.noticeError(error);
}
