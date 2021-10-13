import { useContext, useMemo, useEffect, useRef, useState } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import AcuantContext from '../context/acuant';
import useAsset from '../hooks/use-asset';
import useInstanceId from '../hooks/use-instance-id';
import useImmutableCallback from '../hooks/use-immutable-callback';

/**
 * @enum {string}
 */
const CaptureStatus = {
  ALIGN: 'ALIGN',
  MOVE_CLOSER: 'MOVE_CLOSER',
  TAP_TO_CAPTURE: 'TAP_TO_CAPTURE',
  CAPTURING: 'CAPTURING',
};

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
 *   | null                     // Cropping failure (SDK v11.4.3, L753)
 *   | undefined                // Cropping failure (SDK v11.4.3, L960)
 *   | 'Camera not supported.'  // Camera not supported (SDK v11.4.3, L74, L798)
 *   | 'already started.'       // Capture already started (SDK v11.4.3, L565)
 *   | 'already started'        // Capture already started (SDK v11.4.3, L580)
 *   | 'Missing HTML elements.' // Required page elements are not available (SDK v11.4.3, L568)
 *   | MediaStreamError         // User or system denied camera access (SDK v11.4.3, L544)
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
 * @typedef {(error:AcuantCaptureFailureError)=>void} AcuantFailureCallback
 */

/**
 * @typedef AcuantCaptureCanvasProps
 *
 * @prop {AcuantSuccessCallback} onImageCaptureSuccess Success callback.
 * @prop {AcuantFailureCallback} onImageCaptureFailure Failure callback.
 */

/**
 * Returns the computed capture status based on current capture type and frame state.
 *
 * @param {AcuantCaptureType} captureType Current capture type.
 * @param {AcuantFrameState} frameState Current frame state.
 *
 * @return {CaptureStatus}
 */
function getCaptureStatus(captureType, frameState) {
  // Acuant internally updates UI state to "Tap to Capture" but does _not_ invoke the
  // `onFrameAvailable` callback, so we have to track `captureType` separately.
  if (captureType === 'TAP' || frameState === AcuantUIState.TAP_TO_CAPTURE) {
    return CaptureStatus.TAP_TO_CAPTURE;
  }

  switch (frameState) {
    case AcuantDocumentState.GOOD_DOCUMENT:
      return CaptureStatus.CAPTURING;
    case AcuantDocumentState.SMALL_DOCUMENT:
      return CaptureStatus.MOVE_CLOSER;
    default:
      return CaptureStatus.ALIGN;
  }
}

/**
 * Returns the translation key to use for the status text based on current capture status.
 *
 * @param {CaptureStatus} captureStatus
 *
 * @return {string}
 */
function getStatusLabelKey(captureStatus) {
  switch (captureStatus) {
    case CaptureStatus.CAPTURING:
      // i18n-tasks-use t('doc_auth.accessible_labels.status_capturing')
      return 'doc_auth.accessible_labels.status_capturing';
    case CaptureStatus.MOVE_CLOSER:
      // i18n-tasks-use t('doc_auth.accessible_labels.status_move_closer')
      return 'doc_auth.accessible_labels.status_move_closer';
    case CaptureStatus.TAP_TO_CAPTURE:
      // i18n-tasks-use t('doc_auth.accessible_labels.status_tap_to_capture')
      return 'doc_auth.accessible_labels.status_tap_to_capture';
    default:
      // i18n-tasks-use t('doc_auth.accessible_labels.status_align')
      return 'doc_auth.accessible_labels.status_align';
  }
}

/**
 * @param {AcuantCaptureCanvasProps} props Component props.
 */
function AcuantCaptureCanvas({
  onImageCaptureSuccess = () => {},
  onImageCaptureFailure = () => {},
}) {
  const { isReady } = useContext(AcuantContext);
  const { getAssetPath } = useAsset();
  const { t } = useI18n();
  const instanceId = useInstanceId();
  const [hasCaptured, setHasCaptured] = useState(false);
  const canvasRef = useRef(/** @type {(HTMLCanvasElement & {callback: function})?} */ (null));
  const onCropped = useImmutableCallback(
    (response) => {
      if (response) {
        onImageCaptureSuccess(response);
      } else {
        onImageCaptureFailure(response);
      }
    },
    [onImageCaptureSuccess, onImageCaptureFailure],
  );
  const [captureType, setCaptureType] = useState(/** @type {AcuantCaptureType} */ ('AUTO'));
  const [frameState, setFrameState] = useState(
    /** @type {AcuantFrameState} */ (AcuantDocumentState.NO_DOCUMENT),
  );
  const captureStatus = useMemo(() => getCaptureStatus(captureType, frameState), [
    captureType,
    frameState,
  ]);

  useEffect(() => {
    if (canvasRef.current) {
      // Acuant SDK assigns a callback property to the canvas when it switches to its "Tap to
      // Capture" mode (Acuant SDK v11.4.4, L158). Infer capture type by presence of the property.
      defineObservableProperty(canvasRef.current, 'callback', (callback) => {
        setCaptureType(callback ? 'TAP' : 'AUTO');
      });
    }
  }, []);

  useEffect(() => {
    if (isReady) {
      setHasCaptured(false);
      /** @type {AcuantGlobal} */ (window).AcuantCameraUI.start(
        {
          onFrameAvailable(result) {
            setFrameState(result.state);
          },
          onCaptured() {
            setHasCaptured(true);
          },
          onCropped,
        },
        onImageCaptureFailure,
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

    return () => {
      if (isReady) {
        /** @type {AcuantGlobal} */ (window).AcuantCameraUI.end();
      }
    };
  }, [isReady]);

  // The video element is never visible to the user, but it needs to be present
  // in the DOM for the Acuant SDK to capture the feed from the camera.

  return (
    <>
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
      {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
      <video id="acuant-player" controls autoPlay playsInline style={{ display: 'none' }} />
      <div id="acuant-sdk-capture-view">
        <canvas
          id="acuant-video-canvas"
          ref={canvasRef}
          tabIndex={0}
          aria-labelledby={`acuant-sdk-heading-${instanceId}`}
          aria-describedby={`acuant-sdk-instructions-${instanceId}`}
          style={{
            width: '100%',
            position: 'absolute',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
          }}
        >
          <h2 key="label" id={`acuant-sdk-heading-${instanceId}`}>
            {t('doc_auth.accessible_labels.camera_video_capture_label')}
          </h2>
          {captureType !== 'TAP' && (
            <p key="description" id={`acuant-sdk-instructions-${instanceId}`}>
              {t('doc_auth.accessible_labels.camera_video_capture_instructions')}
            </p>
          )}
          <button key="button" type="button" disabled={captureType !== 'TAP'}>
            {t('doc_auth.buttons.take_picture')}
          </button>
        </canvas>
        <div role="status" aria-live="polite" className="usa-sr-only">
          {isReady && !hasCaptured ? t(getStatusLabelKey(captureStatus)) : null}
        </div>
      </div>
    </>
  );
}

export default AcuantCaptureCanvas;
