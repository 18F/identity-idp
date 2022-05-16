import { useContext } from 'react';
import { StartOverOrCancel as FlowStartOverOrCancel } from '@18f/identity-verify-flow';
import UploadContext from '../context/upload';

function StartOverOrCancel() {
  const { flowPath } = useContext(UploadContext);

  return <FlowStartOverOrCancel canStartOver={flowPath !== 'hybrid'} />;
}

export default StartOverOrCancel;
