import React, { useEffect } from 'react';
import PropTypes from 'prop-types';

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
