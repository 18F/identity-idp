import { useState } from 'react';

/**
 * @param {number=} initialCount Optional initial count.
 *
 * @return {[count: number, incrementCount: () => void]}
 */
function useCounter(initialCount = 0) {
  const [count, setCount] = useState(initialCount);

  const incrementCount = () => setCount((prevCount) => prevCount + 1);

  return [count, incrementCount];
}

export default useCounter;
