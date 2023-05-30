import { trackEvent } from '@18f/identity-analytics';

export type PromptBeforeNavigateOptions = {
  stillOnPageInterval: number;
  // trackEvent: (eventName: string, attributes?: Record<string, unknown>) => void;
};

const defaults = {
  stillOnPageInterval: 7500,
  // trackEvent: analytics.trackEvent,
};

/**
 * Configures the window.onbeforeunload handler such that the user will be prompted before
 * reloading or navigating away
 * @param options {PromptBeforeNavigateOptions}
 * @returns {() => void} A function that, when called, will "clean up" -- restore the prior onbeforeunload handler and cancel any pending timeouts.
 */
export function promptOnNavigate(
  options: Partial<PromptBeforeNavigateOptions> = defaults,
): () => void {
  const { stillOnPageInterval } = {
    ...defaults,
    ...options,
  };

  let stillOnPageTimer: NodeJS.Timeout | undefined;

  function handleBeforeUnload(ev: BeforeUnloadEvent) {
    ev.preventDefault();
    ev.returnValue = '';

    trackEvent('Prompt before navigate');

    if (stillOnPageTimer) {
      clearTimeout(stillOnPageTimer);
    }

    stillOnPageTimer = setTimeout(() => {
      stillOnPageTimer = undefined;
      trackEvent('Prompt before navigate user still on page', {
        interval: stillOnPageInterval,
      });
    }, options.stillOnPageInterval);
  }

  const prevHandler = window.onbeforeunload;
  window.onbeforeunload = handleBeforeUnload;

  return () => {
    if (window.onbeforeunload === handleBeforeUnload) {
      window.onbeforeunload = prevHandler;
    }
    if (stillOnPageTimer) {
      clearTimeout(stillOnPageTimer);
      stillOnPageTimer = undefined;
    }
  };
}
