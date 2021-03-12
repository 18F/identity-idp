const LOGGER_ENDPOINT = '/api/logger';

/**
 * Logs an event.
 *
 * @param {string} event Event name.
 * @param {object=} payload Payload object.
 *
 * @return {Promise<Response>}
 */
export function trackEvent(event, payload) {
  return window.fetch(LOGGER_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ event, payload }),
  });
}
