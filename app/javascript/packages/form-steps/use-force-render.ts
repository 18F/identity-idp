import { useState } from 'react';

function useForceRender() {
  const [, setState] = useState(undefined as number | undefined);

  return () => setState((prevState = 0) => 1 - prevState);
}

export default useForceRender;
