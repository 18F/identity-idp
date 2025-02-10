import { useCallback, useContext, useEffect, useRef, useState } from 'react';

import { getAssetPath } from '@18f/identity-assets';
import { useI18n } from '@18f/identity-react-i18n';
import AcuantContext from '../context/acuant';
import { useObservableProperty } from '../hooks/use-observable-property';

function AcuantCaptureCanvas() {
  const { isReady, acuantCaptureMode, setAcuantCaptureMode } = useContext(AcuantContext);
  const { t } = useI18n();
  const cameraRef = useRef(/** @type {HTMLDivElement?} */ (null));
  const [canvas, setCanvas] = useState(/** @type {HTMLElement? } */ (null));

  useEffect(() => {
    const onAcuantCameraCreated = () => setCanvas(document.getElementById('acuant-ui-canvas'));
    cameraRef.current?.addEventListener('acuantcameracreated', onAcuantCameraCreated);
    return () =>
      cameraRef.current?.removeEventListener('acuantcameracreated', onAcuantCameraCreated);
  }, [cameraRef.current]);

  const onCallback = useCallback(
    (callback) => {
      setAcuantCaptureMode(callback ? 'TAP' : 'AUTO');
    },
    [setAcuantCaptureMode],
  );

  // Acuant SDK assigns a callback property to the canvas when it switches to its "Tap to
  // Capture" mode (Acuant SDK v11.4.4, L158). Infer capture type by presence of the property.
  useObservableProperty(canvas, 'callback', onCallback);

  const clickCanvas = () => document.getElementById('acuant-ui-canvas')?.click();

  return (
    <>
      {!isReady && (
        <img
          src={getAssetPath('loading-badge.gif')}
          alt=""
          width="144"
          height="144"
          className="acuant-capture-canvas__spinner"
        />
      )}
      <h2 className="usa-sr-only">{t('doc_auth.accessible_labels.camera_video_capture_label')}</h2>
      {acuantCaptureMode !== 'TAP' && (
        <p className="usa-sr-only">
          {t('doc_auth.accessible_labels.camera_video_capture_instructions')}
        </p>
      )}
      <div id="acuant-camera" ref={cameraRef} className="acuant-capture-canvas__camera" />
      <button
        type="button"
        onClick={clickCanvas}
        disabled={acuantCaptureMode !== 'TAP'}
        className="usa-sr-only"
      >
        {t('doc_auth.buttons.take_picture')}
      </button>
    </>
  );
}

export default AcuantCaptureCanvas;
