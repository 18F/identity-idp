import { useContext } from 'react';
import { getAssetPath } from '@18f/identity-assets';
import { FullScreen } from '@18f/identity-components';
import AcuantContext from '../context/acuant';

function LoadingSpinner() {
  return (
    <img
      src={getAssetPath('loading-badge.gif')}
      alt=""
      width="144"
      height="144"
      className="acuant-capture-canvas__spinner"
    />
  );
}

function AcuantSelfieCaptureCanvas({ fullScreenRef, onRequestClose, fullScreenLabel }) {
  const { isReady } = useContext(AcuantContext);
  return (
    <FullScreen ref={fullScreenRef} label={fullScreenLabel} onRequestClose={onRequestClose}>
      {!isReady ? <LoadingSpinner /> : <div id="acuant-face-capture-container" />}
    </FullScreen>
  );
}

export default AcuantSelfieCaptureCanvas;
