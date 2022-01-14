import { useContext, useEffect } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import useImmutableCallback from '../hooks/use-immutable-callback';
import AcuantContext from '../context/acuant';

/** @typedef {import('../context/acuant').AcuantJavaScriptWebSDK} AcuantJavaScriptWebSDK */

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
 * Capture type.
 *
 * @typedef {'AUTO'|'TAP'} AcuantCaptureType
 */

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
 *   | undefined // Cropping failure (SDK v11.5.0, L1171)
 *   | 'Camera not supported.' // Camera not supported (SDK v11.5.0, L978)
 *   | 'already started.' // Capture already started (SDK v11.5.0, L724)
 *   | 'Missing HTML elements.' // Required page elements are not available (SDK v11.5.0, L727)
 *   | Error // User or system denied camera access (SDK v11.5.0, L673)
 *   | "Expected div with 'acuant-camera' id" // Failure to setup due to missing element (SDK v11.5.0, L706)
 *   | 'Live capture has previously failed and was called again. User was sent to manual capture.' // Previous failure (SDK v11.5.0, L698)
 *   | 'sequence-break' // iOS 15 sequence break (SDK v11.5.0, L1327)
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
 * @typedef {(error?: AcuantCaptureFailureError, code?: string) => void} AcuantFailureCallback
 */

/**
 * @typedef AcuantCameraContextProps
 *
 * @prop {AcuantSuccessCallback} onImageCaptureSuccess Success callback.
 * @prop {AcuantFailureCallback} onImageCaptureFailure Failure callback.
 * @prop {() => void} onCropStart Crop started callback, invoked after capture is made and before
 * image has been evaluated.
 * @prop {import('react').ReactNode} children Element to render while camera is active.
 */

/**
 * @param {AcuantCameraContextProps} props
 */
function AcuantCamera({
  onImageCaptureSuccess = () => {},
  onImageCaptureFailure = () => {},
  onCropStart = () => {},
  children,
}) {
  const { isReady } = useContext(AcuantContext);
  const { t } = useI18n();
  const onCropped = useImmutableCallback(
    (response) => {
      if (response) {
        onImageCaptureSuccess(response);
      } else {
        onImageCaptureFailure();
      }
    },
    [onImageCaptureSuccess],
  );

  useEffect(() => {
    if (isReady) {
      /** @type {AcuantGlobal} */ (window).AcuantCameraUI.start(
        {
          onCaptured: onCropStart,
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

  return <>{children}</>;
}

export default AcuantCamera;
