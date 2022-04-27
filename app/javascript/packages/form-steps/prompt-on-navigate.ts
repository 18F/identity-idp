import { useLayoutEffect } from 'react';

/**
 * While mounted, prompts the user to confirm navigation.
 */
function PromptOnNavigate() {
  // Use `useLayoutEffect` to guarantee that event unbinding occurs synchronously.
  //
  // See: https://reactjs.org/blog/2020/08/10/react-v17-rc.html#effect-cleanup-timing
  useLayoutEffect(() => {
    function onBeforeUnload(event) {
      event.preventDefault();
      event.returnValue = '';
    }

    window.onbeforeunload = onBeforeUnload;
    return () => {
      window.onbeforeunload = null;
    };
  });

  return null;
}

export default PromptOnNavigate;
