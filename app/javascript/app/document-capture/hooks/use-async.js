import { useState, useCallback } from 'react';
import useIfStillMounted from './use-if-still-mounted';

/**
 * @typedef SuspenseResource
 *
 * @prop {()=>any} read Resource reader, called from a descendent of a Suspense
 *                      element. The reader will either throw an error, throw
 *                      the pending promise, or return the value of the resolved
 *                      promise upon completion.
 */

/**
 * Given a function which returns a promise, returns a Suspense resource object.
 * The resource object can be read from a descendent of a Suspense element,
 * allowing for fallback states for loading or error handling. Any additional
 * arguments are passed through to the promise creator, and are treated as
 * dependencies to trigger a new promise to be issued.
 *
 * @see https://reactjs.org/docs/concurrent-mode-suspense.html
 *
 * @param {(...args:any)=>Promise} createPromise Promise creator.
 * @param {...any}                 args          Additional arguments to pass to
 *                                               promise creator.
 *
 * @return {SuspenseResource} Suspense resource object.
 */
function useAsync(createPromise, ...args) {
  const ifStillMounted = useIfStillMounted();
  const [data, setData] = useState();
  const [hasData, setHasData] = useState(false);
  const [error, setError] = useState();
  const [hasError, setHasError] = useState(false);
  const read = useCallback(
    () =>
      createPromise(...args)
        .then(
          ifStillMounted((nextData) => {
            setData(nextData);
            setHasData(true);
          }),
        )
        .catch(
          ifStillMounted((nextError) => {
            setError(nextError);
            setHasError(true);
          }),
        ),
    args,
  );

  return {
    read() {
      const promise = read();

      if (hasData) {
        return data;
      }

      if (hasError) {
        throw error;
      }

      throw promise;
    },
  };
}

export default useAsync;
