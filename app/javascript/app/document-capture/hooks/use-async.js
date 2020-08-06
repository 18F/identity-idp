import { useState } from 'react';

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
  const [read] = useState(() => {
    let hasData = false;
    let data;
    let hasError = false;
    let error;

    const promise = createPromise(...args)
      .then((nextData) => {
        hasData = true;
        data = nextData;
      })
      .catch((nextError) => {
        hasError = true;
        error = nextError;
      });

    return () => {
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
