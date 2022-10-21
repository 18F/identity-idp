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
 *
 * @return Promise resolving once event has been logged.
 */
export async function trackEvent(event: string, payload: object = {}): Promise<void> {
  const endpoint = getConfigValue('analyticsEndpoint');
  if (!endpoint) {
    return;
  }

  try {
    await window.fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ event, payload }),
    });
  } catch (error) {
    // An error would only be thrown if a network error occurred during the fetch request, which is
    // a scenario we can ignore. By absorbing the error, it should be assumed that an awaited call
    // to `trackEvent` would never create an interrupt due to a thrown error, since an unsuccessful
    // status code on the request is not an error.
    //
    // See: https://fetch.spec.whatwg.org/#dom-global-fetch
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
