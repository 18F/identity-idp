import { loadPolyfills } from '@18f/identity-polyfill';

const LOGGER_ENDPOINT = '/api/logger';

/**
 * Logs an event.
 *
 * @param {string} event Event name.
 * @param {object=} payload Payload object.
 *
 * @return {Promise<Response>}
 */
export async function trackEvent(event, payload) {
  await loadPolyfills(['fetch']);
  return window.fetch(LOGGER_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ event, payload }),
  });
}
