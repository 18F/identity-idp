import React, { useContext } from 'react';
import PropTypes from 'prop-types';
import useAsync from '../hooks/use-async';
import UploadContext from '../context/upload';
import SuspenseErrorBoundary from './suspense-error-boundary';
import SubmissionComplete from './submission-complete';
import SubmissionPending from './submission-pending';

function Submission({ payload }) {
  const upload = useContext(UploadContext);
  const resource = useAsync(upload, payload);

  return (
    <SuspenseErrorBoundary
      fallback={<SubmissionPending onComplete={() => {}} />}
      errorFallback="Error"
    >
      <SubmissionComplete resource={resource} />
    </SuspenseErrorBoundary>
  );
}

Submission.propTypes = {
  // Disable reason: While normally its advisable for a components prop shape to
  // be well-defined, in this case we expect to be able to send arbitrary data
  // to an endpoint.
  // eslint-disable-next-line react/forbid-prop-types
  payload: PropTypes.any,
};

Submission.defaultProps = {
  payload: undefined,
};

export default Submission;
