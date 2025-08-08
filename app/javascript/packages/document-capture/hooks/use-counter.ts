import { useState } from 'react';

function useCounter(initialCount = 0): [number, () => void, () => void] {
  const [count, setCount] = useState(initialCount);

  const incrementCount = () => setCount((prevCount) => prevCount + 1);
  const resetCount = () => setCount(initialCount);

  return [count, incrementCount, resetCount];
}

export default useCounter;
