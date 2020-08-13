import React from 'react';

/**
 * @typedef Resource
 *
 * @prop {()=>T} read Resource reader.
 *
 * @template T
 */

/**
 * @typedef SubmissionCompleteProps
 *
 * @prop {Resource<any>} resource Resource object.
 */

/**
 * @param {SubmissionCompleteProps} props Props object.
 */
function SubmissionComplete({ resource }) {
  const response = resource.read();

  return <>Finished sending: {JSON.stringify(response)}</>;
}

export default SubmissionComplete;
