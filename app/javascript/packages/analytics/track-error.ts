import trackEvent from './track-event';

/**
 * Logs an error.
 */
function trackError(error: Error, event?: ErrorEvent) {
  const { name, message, stack } = error;
  const { filename } = event || {};

  trackEvent('Frontend Error', { name, message, stack, filename });
}

export default trackError;
