import React, { useContext } from 'react';
import useAsync from '../hooks/use-async';
import UploadContext from '../context/upload';
import SuspenseErrorBoundary from './suspense-error-boundary';
import SubmissionComplete from './submission-complete';
import SubmissionInterstitial from './submission-interstitial';
import CallbackOnMount from './callback-on-mount';

/**
 * @typedef SubmissionProps
 *
 * @prop {Record<string,string>} payload Payload object.
 * @prop {(error:Error)=>void} onError Error callback.
 */

/**
 * @param {SubmissionProps} props Props object.
 */
function Submission({ payload, onError }) {
  const upload = useContext(UploadContext);
  const resource = useAsync(upload, payload);

  return (
    <SuspenseErrorBoundary
      fallback={<SubmissionInterstitial autoFocus />}
      errorFallback={({ error }) => <CallbackOnMount onMount={() => onError(error)} />}
    >
      <SubmissionComplete resource={resource} />
    </SuspenseErrorBoundary>
  );
}

export default Submission;
