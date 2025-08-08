import { useState } from 'react';

interface SuspenseResource<T> {
  read: () => T;
}

function useAsync<T, Args extends any[]>(
  createPromise: (...args: Args) => Promise<T>,
  ...args: Args
): SuspenseResource<T> {
  const [read] = useState(() => {
    let hasData = false;
    let data: T;
    let hasError = false;
    let error: any;

    const promise = createPromise(...args)
      .then((nextData: T) => {
        hasData = true;
        data = nextData;
      })
      .catch((nextError: any) => {
        hasError = true;
        error = nextError;
      });

    return (): T => {
      if (hasData) {
        return data;
      }

      if (hasError) {
        throw error;
      }

      throw promise;
    };
  });

  return { read };
}

export default useAsync;
