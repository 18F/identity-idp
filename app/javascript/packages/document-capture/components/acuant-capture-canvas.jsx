import { useContext, useEffect, useRef, useState } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import FullScreen from './full-screen';
import AcuantContext from '../context/acuant';
import useAsset from '../hooks/use-asset';
import useImmutableCallback from '../hooks/use-immutable-callback';

/** @typedef {import('../context/acuant').AcuantJavaScriptWebSDK} AcuantJavaScriptWebSDK */
/** @typedef {import('./full-screen').FullScreenRefHandle} FullScreenRefHandle */

/**
 * @enum {number}
 */
export const AcuantDocumentState = {
  NO_DOCUMENT: 0,
  SMALL_DOCUMENT: 1,
  GOOD_DOCUMENT: 2,
};

/**
 * @enum {number}
 */
export const AcuantUIState = {
  CAPTURING: -1,
  TAP_TO_CAPTURE: -2,
};

/**
 * @typedef {AcuantDocumentState & AcuantUIState} AcuantFrameState
 */

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

/**
 * @typedef AcuantCameraUIText
 *
 * @prop {string} NONE No document detected.
 * @prop {string} SMALL_DOCUMENT Document does not fill frame.
 * @prop {string?} GOOD_DOCUMENT Document is good and capture is pending.
 * @prop {string} CAPTURING Document is being captured.
 * @prop {string} TAP_TO_CAPTURE Explicit user action to capture after delay.
 */

/**
 * @typedef AcuantCameraUIOptions
 *
 * @prop {AcuantCameraUIText} text Camera UI text strings.
 */

/**
 * Capture type.
 *
 * @typedef {'AUTO'|'TAP'} AcuantCaptureType
 */

/**
 * Document type.
 *
 * 0 = None
 * 1 = ID
 * 2 = Passport
 *
 * @typedef {0|1|2} AcuantDocumentType
 */

/**
 * @typedef {(
 *   | 'Camera not supported.' // Camera not supported (SDK v11.5.0, L978)
 *   | 'already started.' // Capture already started (SDK v11.5.0, L724)
 *   | 'Missing HTML elements.' // Required page elements are not available (SDK v11.5.0, L727)
 *   | Error // User or system denied camera access (SDK v11.5.0, L673)
 *   | "Expected div with 'acuant-camera' id" // Failure to setup due to missing element (SDK v11.5.0, L706)
 *   | 'Live capture has previously failed and was called again. User was sent to manual capture.'
 *   | 'sequence-break' // iOS 15 sequence break (SDK v11.5.0, L1327)
 *   | 'Live capture has previously failed and was called again. User was sent to manual capture.' // Previous failure (SDK v11.5.0, L698)
 * )} AcuantCaptureFailureError
 */

/**
 * @typedef AcuantCameraUICallbacks
 *
 * @prop {(response: AcuantCaptureImage)=>void} onCaptured Document captured callback.
 * @prop {(response: AcuantSuccessResponse?)=>void} onCropped Document cropped callback. Null if
 * cropping error.
 * @prop {(response: AcuantDetectedResult)=>void=} onFrameAvailable Optional frame available
 * callback.
 */

/**
 * @typedef AcuantCameraUI
 *
 * @prop {(
 *   callbacks: AcuantCameraUICallbacks,
 *   onFailure: AcuantFailureCallback,
 *   options?: AcuantCameraUIOptions
 * )=>void} start Start capture.
 * @prop {()=>void} end End capture.
 */

/**
 * @typedef AcuantCamera
 *
 * @prop {(callback: (response: AcuantImage)=>void, errorCallback: function)=>void} start
 * @prop {(callback: AcuantCameraUICallbacks)=>void} startManualCapture
 * @prop {(callback: (response: AcuantImage)=>void)=>void} triggerCapture
 * @prop {(
 *   data: string,
 *   width: number,
 *   height: number,
 *   capType: AcuantCaptureType,
 *   callback: (result: AcuantImage) => void,
 * )=>void} crop
 */

/**
 * @typedef AcuantGlobals
 *
 * @prop {AcuantCameraUI} AcuantCameraUI Acuant camera UI API.
 * @prop {AcuantCamera} AcuantCamera Acuant camera API.
 * @prop {AcuantJavaScriptWebSDK} AcuantJavascriptWebSdk Acuant web SDK.
 */

/**
 * @typedef {typeof window & AcuantGlobals} AcuantGlobal
 */

/**
 * @typedef AcuantCaptureImage
 *
 * @prop {Blob} data Pre-cropped image data.
 * @prop {number} width  Image width.
 * @prop {number} height Image height.
 */

/**
 * @typedef AcuantImage
 *
 * @prop {string} data Base64-encoded image data.
 * @prop {number} width Image width.
 * @prop {number} height Image height.
 */

/**
 * @typedef AcuantDetectedResult
 *
 * @prop {AcuantFrameState} state
 */

/**
 * @typedef AcuantSuccessResponse
 *
 * @prop {AcuantImage} image Image object.
 * @prop {AcuantDocumentType} cardType Document type.
 * @prop {number} glare Detected image glare.
 * @prop {number} sharpness Detected image sharpness.
 * @prop {number} moire Detected image moiré.
 * @prop {number} moireraw Detected image raw moiré.
 * @prop {number} dpi Detected image resolution.
 *
 * @see https://github.com/Acuant/JavascriptWebSDKV11/tree/11.4.3/SimpleHTMLApp#acuantcamera
 */

/**
 * @typedef {(response:AcuantSuccessResponse)=>void} AcuantSuccessCallback
 */

/**
 * @typedef {(error: AcuantCaptureFailureError, code: string) => void} AcuantFailureCallback
 */

/**
 * @typedef AcuantCaptureCanvasProps
 *
 * @prop {AcuantSuccessCallback} onImageCaptureSuccess Success callback.
 * @prop {AcuantFailureCallback} onImageCaptureFailure Failure callback.
 * @prop {boolean} isCapturing Whether Acuant should be capturing.
 * @prop {() => void} onCaptureEnd Callback when full screen dialog is explicitly closed before
 * Acuant capture completes.
 * @prop {() => void} onCameraAccessDeclined Callback when user declines access to camera.
 */

/**
 * Returns true if the given Acuant capture failure was caused by the user declining access to the
 * camera, or false otherwise.
 *
 * @param {import('./acuant-capture-canvas').AcuantCaptureFailureError} error
 *
 * @return {boolean}
 */
export const isAcuantCameraAccessFailure = (error) => error instanceof Error;

/**
 * Pauses default focus trap behaviors for a single tick. If a focus transition occurs during this
 * tick, the focus trap's deactivation will be overridden to prevent any default focus return, in
 * order to avoid a race condition between the intended focus targets.
 *
 * @param {import('focus-trap').FocusTrap} focusTrap
 */
function suspendFocusTrapForAnticipatedFocus(focusTrap) {
  // Pause trap event listeners to prevent focus from being pulled back into the trap container in
  // response to programmatic focus transitions.
  focusTrap.pause();

  const originalFocus = document.activeElement;

  // If an element is focused while behaviors are suspended, prevent the default deactivate from
  // attempting to return focus to any other element.
  const originalDeactivate = focusTrap.deactivate;
  focusTrap.deactivate = (deactivateOptions) => {
    const didChangeFocus = originalFocus !== document.activeElement;
    if (didChangeFocus) {
      deactivateOptions = { ...deactivateOptions, returnFocus: false };
    }

    return originalDeactivate(deactivateOptions);
  };

  // After the current frame, assume that focus was not moved elsewhere, or at least resume original
  // trap behaviors.
  setTimeout(() => {
    focusTrap.deactivate = originalDeactivate;
    focusTrap.unpause();
  }, 0);
}

/**
 * @param {AcuantCaptureCanvasProps} props Component props.
 */
function AcuantCaptureCanvas({
  onImageCaptureSuccess = () => {},
  onImageCaptureFailure = () => {},
  onCameraAccessDeclined = () => {},
  isCapturing,
  onCaptureEnd,
}) {
  const { isReady } = useContext(AcuantContext);
  const { getAssetPath } = useAsset();
  const { t } = useI18n();
  const cameraRef = useRef(/** @type {HTMLDivElement?} */ (null));
  const onCropped = useImmutableCallback(
    (response) => {
      if (response) {
        onImageCaptureSuccess(response);
      }
    },
    [onImageCaptureSuccess],
  );
  const [captureType, setCaptureType] = useState(/** @type {AcuantCaptureType} */ ('AUTO'));

  useEffect(() => {
    if (cameraRef.current) {
      cameraRef.current.addEventListener('acuantcameracreated', () => {
        const canvas = document.getElementById('acuant-ui-canvas');
        // Acuant SDK assigns a callback property to the canvas when it switches to its "Tap to
        // Capture" mode (Acuant SDK v11.4.4, L158). Infer capture type by presence of the property.
        defineObservableProperty(canvas, 'callback', (callback) => {
          setCaptureType(callback ? 'TAP' : 'AUTO');
        });
      });
    }
  }, []);

  /** @type {AcuantCameraUICallbacks} */
  const callbacks = { onCaptured() {}, onCropped };

  useEffect(() => {
    if (isReady && isCapturing) {
      /** @type {AcuantGlobal} */ (window).AcuantCameraUI.start(
        callbacks,
        /** @type {AcuantFailureCallback} */ ((error, code) => {
          const {
            SEQUENCE_BREAK_CODE,
            REPEAT_FAIL_CODE,
          } = /** @type {AcuantGlobal} */ (window).AcuantJavascriptWebSdk;

          if (isAcuantCameraAccessFailure(error)) {
            onCameraAccessDeclined();

            if (fullScreenRef.current?.focusTrap) {
              suspendFocusTrapForAnticipatedFocus(fullScreenRef.current.focusTrap);
            }
          } else if (code === SEQUENCE_BREAK_CODE) {
            // Sequence break error won't automatically start manual capture, so start it.
            /** @type {AcuantGlobal} */ (window).AcuantCamera.startManualCapture(callbacks);
            onCaptureEnd();
          } else if (code !== REPEAT_FAIL_CODE) {
            onImageCaptureFailure(error, code);
          } else {
            onCaptureEnd();
          }
        }),
        {
          text: {
            NONE: t('doc_auth.info.capture_status_none'),
            SMALL_DOCUMENT: t('doc_auth.info.capture_status_small_document'),
            GOOD_DOCUMENT: null,
            CAPTURING: t('doc_auth.info.capture_status_capturing'),
            TAP_TO_CAPTURE: t('doc_auth.info.capture_status_tap_to_capture'),
          },
        },
      );
    }

    return () => {};
  }, [isReady, isCapturing]);

  if (!isCapturing) {
    return null;
  }

  return (
    <FullScreen
      ref={fullScreenRef}
      label={t('doc_auth.accessible_labels.document_capture_dialog')}
      onRequestClose={onCaptureEnd}
      bgColor="black"
    >
      {!isReady && (
        <img
          src={getAssetPath('spinner.gif')}
          srcSet={`
            ${getAssetPath('spinner.gif')},
            ${getAssetPath('spinner@2x.gif')} 2x
          `}
          alt=""
          width="144"
          height="144"
          style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            transform: 'translate(-72px, -72px)',
          }}
        />
      )}
      <h2 className="usa-sr-only">{t('doc_auth.accessible_labels.camera_video_capture_label')}</h2>
      {captureType !== 'TAP' && (
        <p className="usa-sr-only">
          {t('doc_auth.accessible_labels.camera_video_capture_instructions')}
        </p>
      )}
      <div
        id="acuant-camera"
        ref={cameraRef}
        style={{
          width: '100%',
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
        }}
      />
      <button type="button" disabled={captureType !== 'TAP'} className="usa-sr-only">
        {t('doc_auth.buttons.take_picture')}
      </button>
    </FullScreen>
  );
}

export default AcuantCaptureCanvas;
