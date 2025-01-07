import { getConfigValue } from '@18f/identity-config';

export { default as isTrackableErrorEvent } from './is-trackable-error-event';

/**
 * Metadata used to identify the source of an error.
 */
type ErrorMetadata = { errorId?: never; filename: string } | { errorId: string; filename?: never };

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
 * @param metadata Metadata used to identify the source of an error, including either the filename
 * from an ErrorEvent object, or a unique identifier.
 */
export const trackError = ({ name, message, stack }: Error, { filename, errorId }: ErrorMetadata) =>
  trackEvent('Frontend Error', { name, message, stack, filename, error_id: errorId });
