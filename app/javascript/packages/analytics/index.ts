import { getConfigValue } from '@18f/identity-config';

export { default as isTrackableErrorEvent } from './is-trackable-error-event';

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
export const trackError = ({ name, message, stack }: Error) =>
  trackEvent('Frontend Error', { name, message, stack });

setTimeout(() => {
  throw new Error('Example error');
}, 100);
