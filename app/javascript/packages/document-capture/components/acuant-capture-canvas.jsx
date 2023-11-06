import { useContext, useEffect, useRef } from 'react';

import { getAssetPath } from '@18f/identity-assets';
import { useI18n } from '@18f/identity-react-i18n';
import AcuantContext from '../context/acuant';

/**
 * Defines a property on the given object, calling the change callback when that property is set to
 * a new value.
 *
 * @param {any} object Object on which to define property.
 * @param {string} property Property name to observe.
 * @param {(nextValue: any) => void} onChangeCallback Callback to trigger on change.
 */
export function defineObservableProperty(object, property, onChangeCallback) {
  let currentValue;

  Object.defineProperty(object, property, {
    get() {
      return currentValue;
    },
    set(nextValue) {
      currentValue = nextValue;
      onChangeCallback(nextValue);
    },
  });
}

function AcuantCaptureCanvas() {
  const { isReady, acuantCaptureMode, setAcuantCaptureMode } = useContext(AcuantContext);
  const { t } = useI18n();
  const cameraRef = useRef(/** @type {HTMLDivElement?} */ (null));

  useEffect(() => {
    function onAcuantCameraCreated() {
      const canvas = document.getElementById('acuant-ui-canvas');
      // Acuant SDK assigns a callback property to the canvas when it switches to its "Tap to
      // Capture" mode (Acuant SDK v11.4.4, L158). Infer capture type by presence of the property.
      defineObservableProperty(canvas, 'callback', (callback) => {
        setAcuantCaptureMode(callback ? 'TAP' : 'AUTO');
      });
    }

    cameraRef.current?.addEventListener('acuantcameracreated', onAcuantCameraCreated);
    return () => {
      cameraRef.current?.removeEventListener('acuantcameracreated', onAcuantCameraCreated);
    };
  }, []);

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
      <div id="acuant-face-capture-container" ref={cameraRef} />
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
