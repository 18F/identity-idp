import { useContext } from 'react';
import { getAssetPath } from '@18f/identity-assets';
import { useI18n } from '@18f/identity-react-i18n';
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

function AcuantSelfieCaptureCanvas({ imageCaptureText, onSelfieCaptureClosed }) {
  const { isReady } = useContext(AcuantContext);
  const { t } = useI18n();
  // The Acuant SDK script AcuantPassiveLiveness attaches to whatever element has
  // this id. It then uses that element as the root for the full screen selfie capture
  const acuantCaptureContainerId = 'acuant-face-capture-container';
  return (
    <>
      {!isReady && <LoadingSpinner />}
      <div id={acuantCaptureContainerId} />
      <p aria-live="assertive" className="document-capture-selfie-feedback">
        {imageCaptureText}
      </p>
      <button type="button" onClick={onSelfieCaptureClosed} className="usa-sr-only">
        {t('doc_auth.buttons.take_picture')}
      </button>
    </>
  );
}

export default AcuantSelfieCaptureCanvas;
