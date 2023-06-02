import { trackEvent } from '@18f/identity-analytics';

export type PromptOnNavigateOptions = {
  stillOnPageIntervalsInSeconds: number[];
};

const defaults = {
  stillOnPageIntervalsInSeconds: [5, 15, 30],
};

export const PROMPT_EVENT = 'User prompted before navigation';

export const STILL_ON_PAGE_EVENT = 'User prompted before navigation and still on page';

/**
 * Configures the window.onbeforeunload handler such that the user will be prompted before
 * reloading or navigating away
 * @param options {PromptOnNavigateOptions}
 * @returns {() => void} A function that, when called, will "clean up" -- restore the prior onbeforeunload handler and cancel any pending timeouts.
 */
export function promptOnNavigate(options: PromptOnNavigateOptions = defaults): () => void {
  let stillOnPageTimer: number | undefined;

  function handleBeforeUnload(ev: BeforeUnloadEvent) {
    ev.preventDefault();
    ev.returnValue = '';

    trackEvent(PROMPT_EVENT);

    const stillOnPageIntervalsInSeconds = [...options.stillOnPageIntervalsInSeconds];
    let elapsed = 0;

    function scheduleNextStillOnPagePing() {
      const interval = stillOnPageIntervalsInSeconds.shift();
      if (interval === undefined) {
        return;
      }

      if (stillOnPageTimer) {
        clearTimeout(stillOnPageTimer);
        stillOnPageTimer = undefined;
      }

      const offsetFromNow = interval - elapsed;
      elapsed = interval;

      stillOnPageTimer = window.setTimeout(() => {
        trackEvent(STILL_ON_PAGE_EVENT, {
          seconds: elapsed,
        });
        scheduleNextStillOnPagePing();
      }, offsetFromNow * 1000);
    }

    scheduleNextStillOnPagePing();
  }

  const prevHandler = window.onbeforeunload;
  window.onbeforeunload = handleBeforeUnload;

  return () => {
    if (window.onbeforeunload === handleBeforeUnload) {
      window.onbeforeunload = prevHandler;
    }
    if (stillOnPageTimer) {
      window.clearTimeout(stillOnPageTimer);
      stillOnPageTimer = undefined;
    }
  };
}
