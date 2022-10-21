import { useState, useContext, useRef } from 'react';
import CallbackOnMount from './callback-on-mount';
import UploadContext from '../context/upload';

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
 * @param {SubmissionCompleteProps} props Props object.
 */
function SubmissionComplete({ resource }) {
  const [, setRetryError] = useState(/** @type {Error=} */ (undefined));
  const sleepTimeout = useRef(/** @type {number=} */ (undefined));
  const { statusPollInterval } = useContext(UploadContext);
  const response = resource.read();

  function handleResponse() {
    if (response.isPending) {
      if (Number.isFinite(statusPollInterval)) {
        sleepTimeout.current = window.setTimeout(() => {
          setRetryError(() => {
            throw new RetrySubmissionError();
          });
        }, statusPollInterval);
      }
    } else {
      /** @type {HTMLFormElement?} */
      const form = document.querySelector('.js-document-capture-form');
      form?.submit();
    }

    return () => window.clearTimeout(sleepTimeout.current);
  }

  return <CallbackOnMount onMount={handleResponse} />;
}

export default SubmissionComplete;
