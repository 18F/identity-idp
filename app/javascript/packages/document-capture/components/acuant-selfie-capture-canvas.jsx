import { getAssetPath } from '@18f/identity-assets';
import { FullScreen } from '@18f/identity-components';

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

function AcuantSelfieCaptureCanvas({ loading, fullScreenRef, onRequestClose, fullScreenLabel }) {
  return loading ? (
    <FullScreenLoadingSpinner
      fullScreenRef={fullScreenRef}
      onRequestClose={onRequestClose}
      fullScreenLabel={fullScreenLabel}
    />
  ) : (
    <div id="acuant-face-capture-container" />
  );
}

export default AcuantSelfieCaptureCanvas;
