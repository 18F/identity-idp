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

  // This solves a fairly nasty bug for screenreader users where the screenreader focus would jump away
  // from the capture button (added by Acuant SDK) to the button in this component. Specifically we
  // need to detect when Acuant actually hydrates in their capture screen and hide the button.
  // See PR 10668 for more information.
  const elementInShadow = document
    ?.getElementById('acuant-face-capture-camera')
    ?.shadowRoot?.getElementById('cameraContainer');
  const loadedAcuantCamera = !!elementInShadow;

  return (
    <>
      {!isReady && <LoadingSpinner />}
      <div id={acuantCaptureContainerId}>
        <p aria-live="assertive">
          {imageCaptureText && <span className="document-capture-selfie-feedback">{imageCaptureText}</span>}
        </p>
      </div>
      {!loadedAcuantCamera && (
        <button type="button" onClick={onSelfieCaptureClosed} className="usa-sr-only">
          {t('doc_auth.buttons.close')}
        </button>
      )}
    </>
  );
}

export default AcuantSelfieCaptureCanvas;
