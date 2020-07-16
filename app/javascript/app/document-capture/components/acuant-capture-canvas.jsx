import React, { useRef, useEffect } from 'react';
import PropTypes from 'prop-types';

function AcuantCaptureCanvas({ onImageCaptureSuccess, onImageCaptureFailure }) {
  const isCapturing = useRef(false);

  useEffect(() => {
    /**
     * Creates a new callback function which also sets the internal component
     * state to mark capture as completed.
     *
     * @param {Function} callback Original callback.
     *
     * @return {Function} Enhanced callback.
     */
    const createOnComplete = (callback) => (result) => {
      isCapturing.current = false;
      callback(result);
    };

    isCapturing.current = true;

    window.AcuantCameraUI.start(
      createOnComplete(onImageCaptureSuccess),
      createOnComplete(onImageCaptureFailure),
    );

    return () => {
      // If capturing while component unmounts, end the capture.
      if (isCapturing.current) {
        window.AcuantCameraUI.end();
      }
    };
  }, []);

  // The video element is never visible to the user, but it needs to be present
  // in the DOM for the Acuant SDK to capture the feed from the camera.

  return (
    <>
      {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
      <video
        id="acuant-player"
        controls
        autoPlay
        playsInline
        style={{ display: 'none' }}
      />
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
