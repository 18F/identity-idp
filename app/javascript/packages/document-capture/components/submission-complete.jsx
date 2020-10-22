import React, { useState, useRef, useEffect } from 'react';
import SubmissionInterstitial from './submission-interstitial';

/** @typedef {import('../context/upload').UploadSuccessResponse} UploadSuccessResponse */

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
 * @prop {Resource<UploadSuccessResponse>} resource Resource object.
 */

export class RetrySubmissionError extends Error {}

/**
 * Interval after which to retry submission, in milliseconds.
 *
 * @type {number}
 */
const RETRY_INTERVAL = process.env.NODE_ENV === 'test' ? 0 : 2500;

/**
 * @param {SubmissionCompleteProps} props Props object.
 */
function SubmissionComplete({ resource }) {
  const [, setRetryError] = useState(/** @type {Error=} */ (undefined));
  const sleepTimeout = useRef(/** @type {number=} */ (undefined));
  const response = resource.read();

  useEffect(() => {
    if (response.isPending) {
      sleepTimeout.current = window.setTimeout(() => {
        setRetryError(() => {
          throw new RetrySubmissionError();
        });
      }, RETRY_INTERVAL);
    } else {
      /** @type {HTMLFormElement?} */
      const form = document.querySelector('.js-document-capture-form');
      form?.submit();
    }

    return () => window.clearTimeout(sleepTimeout.current);
  }, []);

  return <SubmissionInterstitial />;
}

export default SubmissionComplete;
