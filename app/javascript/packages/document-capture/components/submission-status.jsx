import React, { useContext } from 'react';
import useAsync from '../hooks/use-async';
import UploadContext from '../context/upload';
import SubmissionComplete from './submission-complete';

function SubmissionStatus() {
  const { getStatus } = useContext(UploadContext);
  const resource = useAsync(getStatus);

  return <SubmissionComplete resource={resource} />;
}

export default SubmissionStatus;
