import { useI18n } from '@18f/identity-react-i18n';
import { getAssetPath } from '@18f/identity-assets';
import { FullScreen } from '@18f/identity-components';

function FullScreenLoadingSpinner({ fullScreenRef, onRequestClose }) {
  const { t } = useI18n();

  return (
    <FullScreen
      ref={fullScreenRef}
      label={t('doc_auth.accessible_labels.document_capture_dialog')}
      onRequestClose={onRequestClose}
    >
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

function AcuantSelfieCaptureCanvas({ loading, fullScreenRef, onRequestClose }) {
  return loading ? (
    <FullScreenLoadingSpinner fullScreenRef={fullScreenRef} onRequestClose={onRequestClose} />
  ) : (
    <div id="acuant-face-capture-container" />
  );
}

export default AcuantSelfieCaptureCanvas;
