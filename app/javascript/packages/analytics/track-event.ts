import { getConfigValue } from '@18f/identity-config';

/**
 * Logs an event.
 *
 * @param event Event name.
 * @param payload Payload object.
 */
function trackEvent(event: string, payload?: object) {
  const endpoint = getConfigValue('analyticsEndpoint');

  // Make analytics requests using sendBeacon(), which can be prioritized appropriately by the
  // browser and have a better chance of succeeding during page unload than fetch().
  if (endpoint && navigator.sendBeacon) {
    navigator.sendBeacon(endpoint, JSON.stringify({ event, payload }));
  }
}

export default trackEvent;
