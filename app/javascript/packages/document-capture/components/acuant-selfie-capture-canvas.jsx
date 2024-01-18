import { useContext } from 'react';
import { getAssetPath } from '@18f/identity-assets';
import { FullScreen } from '@18f/identity-components';
import AcuantContext from '../context/acuant';

function FullScreenLoadingSpinner({ fullScreenRef, onRequestClose, fullScreenLabel }) {
  return (
    <FullScreen ref={fullScreenRef} label={fullScreenLabel} onRequestClose={onRequestClose}>
      <img
        src={getAssetPath('loading-badge.gif')}
        alt=""
        width="144"
        height="144"
        className="acuant-capture-canvas__spinner"
      />
    </FullScreen>
  );
}

function AcuantSelfieCaptureCanvas({
  fullScreenRef,
  onRequestClose,
  fullScreenLabel,
  imageCaptureText,
}) {
  const { isReady } = useContext(AcuantContext);
  // The Acuant SDK script AcuantPassiveLiveness attaches to whatever element has
  // this id. It then uses that element as the root for the full screen selfie capture
  const acuantCaptureContainerId = 'acuant-face-capture-container';
  return isReady ? (
    <div id={acuantCaptureContainerId}>
      <p className="document-capture-selfie-feedback">{imageCaptureText}</p>
    </div>
  ) : (
    <FullScreenLoadingSpinner
      fullScreenRef={fullScreenRef}
      onRequestClose={onRequestClose}
      fullScreenLabel={fullScreenLabel}
    />
  );
}

export default AcuantSelfieCaptureCanvas;
