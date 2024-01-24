export type PromptOnNavigateOptions = {
  stillOnPageIntervalsInSeconds: number[];
};

const defaults = {
  stillOnPageIntervalsInSeconds: [5, 15, 30],
};

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
