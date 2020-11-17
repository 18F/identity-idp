import React, { useContext } from 'react';
import useAsync from '../hooks/use-async';
import UploadContext from '../context/upload';
import SubmissionComplete from './submission-complete';

/**
 * Given an object where some values may be promises, returns a promise which resolves to an object
 * with the same keys and all resolved promise values.
 *
 * @template {Record<string, any>} T
 *
 * @param {T} object
 *
 * @return {Promise<Record<keyof T, any>>} Object with all values resolved.
 */
export async function resolveObjectValues(object) {
  const resolved = {};

  for (const [key, value] of Object.entries(object)) {
    // Disable reason: While typically inadvisable since await blocks continued iteration of the
    // loop, the intent of the function is to not resolve until all member values have settled.
    // eslint-disable-next-line no-await-in-loop
    resolved[key] = await value;
  }

  return /** @type {Record<keyof T, any>} */ (resolved);
}

/**
 * Returns a function which runs an array of promise creator functions in series (sequential) order.
 *
 * @param {Array<(...args:any)=>Promise<any>>} promiseCreators Promise creator functions.
 *
 * @return {(...args:any)=>Promise<any>} Promise resolving once all promise creators in series have
 * run.
 */
export const series = (...promiseCreators) => (value) =>
  promiseCreators.reduce((current, next) => current.then(next), Promise.resolve(value));

/**
 * @typedef SubmissionProps
 *
 * @prop {Record<string,string>} payload Payload object.
 */

/**
 * @param {SubmissionProps} props Props object.
 */
function Submission({ payload }) {
  const { upload } = useContext(UploadContext);
  const resource = useAsync(series(resolveObjectValues, upload), payload);

  return <SubmissionComplete resource={resource} />;
}

export default Submission;
