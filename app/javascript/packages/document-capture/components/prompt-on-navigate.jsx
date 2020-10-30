import { useEffect } from 'react';

/**
 * While mounted, prompts the user to confirm navigation.
 */
function PromptOnNavigate() {
  useEffect(() => {
    function onBeforeUnload(event) {
      event.preventDefault();
      event.returnValue = '';
    }

    window.addEventListener('beforeunload', onBeforeUnload);
    return () => window.removeEventListener('beforeunload', onBeforeUnload);
  });

  return null;
}

export default PromptOnNavigate;
