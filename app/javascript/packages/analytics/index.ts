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
export async function trackEvent(event: string, payload?: object): Promise<void> {
  const endpoint = getConfigValue('analyticsEndpoint');

  if (!endpoint) {
    return;
  }

  const eventJson = JSON.stringify({ event, payload });

  // Favor making analytics requests using sendBeacon(), which can be prioritized
  // appropriately by the browser and have a better chance of succeeding during page unload.
  try {
    const blob = new Blob([eventJson], { type: 'application/json' });
    const wasQueued = navigator.sendBeacon(endpoint, blob);
    if (wasQueued) {
      // The browser has promised it will send our request for us -- we can stop now.
      return;
    }
  } catch {}

  // Fall back to fetch() if sendBeacon is not available or if the call to sendBeacon() did
  // not result in the browser actually making the request.
  await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: eventJson,
  }).catch(() => {
    // An error would only be thrown if a network error occurred during the fetch request, which is
    // a scenario we can ignore. By absorbing the error, it should be assumed that an awaited call
    // to `trackEvent` would never create an interrupt due to a thrown error, since an unsuccessful
    // status code on the request is not an error.
    //
    // See: https://fetch.spec.whatwg.org/#dom-global-fetch
  });
}

/**
 * Logs an error.
 *
 * @param error Error object.
 */
export function trackError(error: Error) {
  (globalThis as typeof globalThis & NewRelicGlobals).newrelic?.noticeError(error);
}
