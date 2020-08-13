import React, { useContext } from 'react';
import useAsync from '../hooks/use-async';
import UploadContext from '../context/upload';
import SuspenseErrorBoundary from './suspense-error-boundary';
import SubmissionComplete from './submission-complete';
import SubmissionPending from './submission-pending';

/**
 * @typedef SubmissionProps
 *
 * @prop {Record<string,string>} payload Payload object.
 */

/**
 * @param {SubmissionProps} props Props object.
 */
function Submission({ payload }) {
  const upload = useContext(UploadContext);
  const resource = useAsync(upload, payload);

  return (
    <SuspenseErrorBoundary fallback={<SubmissionPending />} errorFallback="Error">
      <SubmissionComplete resource={resource} />
    </SuspenseErrorBoundary>
  );
}

export default Submission;
