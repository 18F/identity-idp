import React, { useEffect } from 'react';
import PropTypes from 'prop-types';

/**
 * @typedef AcuantImage
 *
 * @prop {string} data   Base64-encoded image data.
 * @prop {number} width  Image width.
 * @prop {number} height Image height.
 */

/**
 * @typedef AcuantSuccessResponse
 *
 * @prop {AcuantImage} image      Image object.
 * @prop {boolean}     isPassport Whether document is passport.
 * @prop {number}      glare      Detected image glare.
 * @prop {number}      sharpness  Detected image sharpness.
 * @prop {number}      dpi        Detected image resolution.
 *
 * @see https://github.com/Acuant/JavascriptWebSDKV11/tree/11.3.3/SimpleHTMLApp#acuantcamera
 */

/**
 * @typedef AcuantCaptureCanvasProps
 *
 * @prop {(response:AcuantSuccessResponse)=>void} onImageCaptureSuccess Success callback.
 * @prop {(error:Error)=>void}                    onImageCaptureFailure Failure callback.
 */

/**
 * @param {AcuantCaptureCanvasProps} props Component props.
 */
function AcuantCaptureCanvas({ onImageCaptureSuccess, onImageCaptureFailure }) {
  useEffect(() => {
    window.AcuantCameraUI.start(onImageCaptureSuccess, onImageCaptureFailure);

    return () => {
      window.AcuantCameraUI.end();
    };
  }, []);

  // The video element is never visible to the user, but it needs to be present
  // in the DOM for the Acuant SDK to capture the feed from the camera.

  return (
    <>
      {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
      <video id="acuant-player" controls autoPlay playsInline style={{ display: 'none' }} />
      <div id="acuant-sdk-capture-view">
        <canvas id="acuant-video-canvas" width="100%" height="auto" />
      </div>
    </>
  );
}

AcuantCaptureCanvas.propTypes = {
  onImageCaptureSuccess: PropTypes.func,
  onImageCaptureFailure: PropTypes.func,
};

AcuantCaptureCanvas.defaultProps = {
  onImageCaptureSuccess: () => {},
  onImageCaptureFailure: () => {},
};

export default AcuantCaptureCanvas;
