import { useContext } from 'react';
import { getAssetPath } from '@18f/identity-assets';
import AcuantContext from '../context/acuant';

function LoadingSpinner() {
  return (
    <img
      src={getAssetPath('loading-badge.gif')}
      alt=""
      width="144"
      height="144"
      className="acuant-capture-canvas__spinner"
      role="img"
    />
  );
}

function AcuantSelfieCaptureCanvas({ imageCaptureText }) {
  const { isReady } = useContext(AcuantContext);
  // The Acuant SDK script AcuantPassiveLiveness attaches to whatever element has
  // this id. It then uses that element as the root for the full screen selfie capture
  const acuantCaptureContainerId = 'acuant-face-capture-container';
  return (
    <>
      {!isReady && <LoadingSpinner />}
      <div id={acuantCaptureContainerId} />
      <p className="document-capture-selfie-feedback">{imageCaptureText}</p>
    </>
  );
}

export default AcuantSelfieCaptureCanvas;
