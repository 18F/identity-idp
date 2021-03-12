import { getPageData } from '@18f/identity-page-data';

/**
 * Logs an event.
 *
 * @param {string} event Event name.
 * @param {Record<string,any>=} payload Payload object.
 *
 * @return {Promise<void>}
 */
export async function trackEvent(event, payload = {}) {
  const endpoint = getPageData('analyticsEndpoint');
  if (endpoint) {
    await window.fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ event, payload }),
    });
  }
}
