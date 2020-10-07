import React, { useContext, useEffect } from 'react';
import AcuantContext from '../context/acuant';
import useAsset from '../hooks/use-asset';
import useI18n from '../hooks/use-i18n';

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
 * @typedef AcuantCameraUICallbacks
 *
 * @prop {(response: AcuantCaptureImage)=>void} onCaptured Document captured callback.
 * @prop {(response: AcuantSuccessResponse?)=>void} onCropped Document cropped callback. Null if
 * cropping error.
 * @prop {(response: object)=>void=} onFrameAvailable Optional frame available callback.
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
 * @typedef AcuantGlobals
 *
 * @prop {AcuantCameraUI} AcuantCameraUI Acuant camera UI API.
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
 * @typedef AcuantSuccessResponse
 *
 * @prop {AcuantImage} image Image object.
 * @prop {AcuantDocumentType} cardType Document type.
 * @prop {number} glare Detected image glare.
 * @prop {number} sharpness Detected image sharpness.
 * @prop {number} dpi Detected image resolution.
 *
 * @see https://github.com/Acuant/JavascriptWebSDKV11/tree/11.4.1/SimpleHTMLApp#acuantcameraui
 */

/**
 * @typedef {(response:AcuantSuccessResponse)=>void} AcuantSuccessCallback
 */

/**
 * @typedef {(error?:Error)=>void} AcuantFailureCallback
 */

/**
 * @typedef AcuantCaptureCanvasProps
 *
 * @prop {AcuantSuccessCallback} onImageCaptureSuccess Success callback.
 * @prop {AcuantFailureCallback} onImageCaptureFailure Failure callback.
 */

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

  useEffect(() => {
    if (isReady) {
      /** @type {AcuantGlobal} */ (window).AcuantCameraUI.start(
        {
          onCaptured() {},
          onCropped(response) {
            if (response) {
              onImageCaptureSuccess(response);
            } else {
              onImageCaptureFailure();
            }
          },
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
          style={{
            width: '100%',
            position: 'absolute',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
          }}
        />
      </div>
    </>
  );
}

export default AcuantCaptureCanvas;
