import { useEffect } from 'react';

function CallbackOnMount({ onMount }) {
  useEffect(() => {
    onMount();
  }, []);

  return null;
}

export default CallbackOnMount;
