import React, { useContext, useEffect } from 'react';
import AcuantContext from '../context/acuant';
import useAsset from '../hooks/use-asset';

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
 *   onError: AcuantFailureCallback
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
        <canvas id="acuant-video-canvas" width="100%" height="auto" />
      </div>
    </>
  );
}

export default AcuantCaptureCanvas;
