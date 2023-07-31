import { useState } from 'react';

type CaptureType = 'AUTO' | 'TAP';

function useAcuantTapOrAutoCapture() {
  const [captureType, setCaptureType] = useState<CaptureType>('AUTO');

  return { captureType, setCaptureType };
}

export default useAcuantTapOrAutoCapture;
