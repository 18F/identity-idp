/**
 * Configures the window.onbeforeunload handler such that the user will be prompted before
 * reloading or navigating away
 * @param options {PromptOnNavigateOptions}
 * @returns {() => void} A function that, when called, will "clean up" -- restore the prior onbeforeunload handler and cancel any pending timeouts.
 */
export function promptOnNavigate(): () => void {
  function handleBeforeUnload(ev: BeforeUnloadEvent) {
    ev.preventDefault();
    ev.returnValue = '';
  }

  const prevHandler = window.onbeforeunload;
  window.onbeforeunload = handleBeforeUnload;

  return () => {
    if (window.onbeforeunload === handleBeforeUnload) {
      window.onbeforeunload = prevHandler;
    }
  };
}
