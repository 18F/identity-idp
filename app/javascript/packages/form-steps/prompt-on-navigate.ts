import { useLayoutEffect } from 'react';
import { promptOnNavigate } from '@18f/identity-prompt-on-navigate';

/**
 * While mounted, prompts the user to confirm navigation.
 */
function PromptOnNavigate() {
  // Use `useLayoutEffect` to guarantee that event unbinding occurs synchronously.
  //
  // See: https://reactjs.org/blog/2020/08/10/react-v17-rc.html#effect-cleanup-timing
  useLayoutEffect(promptOnNavigate);

  return null;
}

export default PromptOnNavigate;
