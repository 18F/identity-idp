import React from 'react';
import CallbackOnMount from './callback-on-mount';
import SubmissionInterstitial from './submission-interstitial';

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
  resource.read();

  function submitCaptureForm() {
    /** @type {HTMLFormElement?} */
    const form = document.querySelector('.js-document-capture-form');
    form?.submit();
  }

  return (
    <>
      <SubmissionInterstitial />
      <CallbackOnMount onMount={submitCaptureForm} />
    </>
  );
}

export default SubmissionComplete;
