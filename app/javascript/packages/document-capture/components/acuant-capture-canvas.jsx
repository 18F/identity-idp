import { useContext, useEffect, useRef } from 'react';
import { getAssetPath } from '@18f/identity-assets';
import { useI18n } from '@18f/identity-react-i18n';
import AcuantContext from '../context/acuant';
import {
  defineObservableProperty,
  removeObservableProperty,
} from '../higher-order/observable-property';

/**
 * Resets a property on the given object, applying the originalDescriptor, if provided,
 * or deleting the property entirely if not.
 *
 * @param {any} object Object on which to define property.
 * @param {string} property Property name to observe.
 * @param {any} originalDescriptor The descriptor to reset the property with.
 */
export function resetObservableProperty(object, property, originalDescriptor) {
  if (object === undefined) {
    return;
  }

  if (originalDescriptor !== undefined) {
    Object.defineProperty(object, property, originalDescriptor);
  } else {
    delete object[property];
  }
}

function AcuantCaptureCanvas() {
  const { isReady, acuantCaptureMode, setAcuantCaptureMode } = useContext(AcuantContext);
  const { t } = useI18n();
  const cameraRef = useRef(/** @type {HTMLDivElement?} */ (null));

  useEffect(() => {
    let canvas;
    let originalDescriptor;

    function onAcuantCameraCreated() {
      canvas = document.getElementById('acuant-ui-canvas');
      if (originalDescriptor === undefined) {
        originalDescriptor = Object.getOwnPropertyDescriptor(canvas, 'callback');
      }

      // Acuant SDK assigns a callback property to the canvas when it switches to its "Tap to
      // Capture" mode (Acuant SDK v11.4.4, L158). Infer capture type by presence of the property.
      defineObservableProperty(canvas, 'callback', (callback) => {
        setAcuantCaptureMode(callback ? 'TAP' : 'AUTO');
      });
    }

    cameraRef.current?.addEventListener('acuantcameracreated', onAcuantCameraCreated);
    return () => {
      const canvas = document.getElementById('acuant-ui-canvas');
      if (canvas) {
        removeObservableProperty(canvas, 'callback');
      }

      cameraRef.current?.removeEventListener('acuantcameracreated', onAcuantCameraCreated);
      resetObservableProperty(canvas, 'callback', originalDescriptor);
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
