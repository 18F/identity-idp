import React, { useRef, useState, useEffect, useCallback, useMemo } from 'react';
import FileImage from './file-image';
import useIfStillMounted from '../hooks/use-if-still-mounted';
import useI18n from '../hooks/use-i18n';

/**
 * @typedef SelfieCaptureProps
 *
 * @prop {Blob?=} value Current value.
 * @prop {(nextValue:Blob?)=>void} onChange Change handler.
 */

/**
 * @param {SelfieCaptureProps} props Props object.
 */
function SelfieCapture({ value, onChange }) {
  const videoRef = useRef(/** @type {HTMLVideoElement?} */ (null));
  const assignVideoRef = useCallback((ref) => {
    if (!ref && videoRef.current && videoRef.current.srcObject instanceof window.MediaStream) {
      videoRef.current.srcObject.getTracks().forEach((track) => track.stop());
    }

    videoRef.current = ref;
  }, []);
  const [isCapturing, setIsCapturing] = useState(false);
  useMemo(() => setIsCapturing(isCapturing && !value), [value]);
  const ifStillMounted = useIfStillMounted();
  const { t } = useI18n();
  useEffect(() => {
    if (!value && !isCapturing) {
      navigator.mediaDevices.getUserMedia({ video: true }).then(
        ifStillMounted((/** @type {MediaStream} */ stream) => {
          if (!videoRef.current) {
            return;
          }

          videoRef.current.srcObject = stream;
          videoRef.current.play();
          setIsCapturing(true);
        }),
      );
    }
  }, [value]);

  function onCapture() {
    if (!videoRef.current) {
      return;
    }

    const canvas = document.createElement('canvas');
    const { videoWidth: width, videoHeight: height } = videoRef.current;
    canvas.height = height;
    canvas.width = height;
    canvas
      .getContext('2d')
      ?.drawImage(videoRef.current, (width - height) / 2, 0, height, height, 0, 0, height, height);
    canvas.toBlob(ifStillMounted(onChange));
  }

  const classes = [
    'selfie-capture',
    isCapturing && 'selfie-capture--capturing',
    value && 'selfie-capture--has-value',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <div className={classes}>
      {value ? (
        <>
          <div className="selfie-capture__preview-heading usa-file-input__preview-heading">
            <span />
            <button
              type="button"
              onClick={() => onChange(null)}
              className="usa-file-input__choose usa-button--unstyled"
            >
              {t('doc_auth.buttons.take_picture_retry')}
            </button>
          </div>
          <FileImage file={value} alt="" className="selfie-capture__preview-image" />
        </>
      ) : (
        <>
          {/* Disable reason: Video is used only for direct capture */}
          {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
          <video ref={assignVideoRef} className="selfie-capture__video" />
          <div className="selfie-capture__frame">
            <div className="selfie-capture__frame-corner" />
            <div className="selfie-capture__frame-corner" />
            <div className="selfie-capture__frame-corner" />
            <div className="selfie-capture__frame-corner" />
          </div>
          <button
            type="button"
            className="selfie-capture__capture"
            aria-label={t('doc_auth.buttons.take_picture')}
            onClick={onCapture}
          >
            <svg
              aria-hidden="true"
              focusable="false"
              data-prefix="fas"
              data-icon="camera"
              role="img"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 512 512"
              className="selfie-capture__capture-icon"
            >
              <path
                fill="currentColor"
                d="M512 144v288c0 26.5-21.5 48-48 48H48c-26.5 0-48-21.5-48-48V144c0-26.5 21.5-48 48-48h88l12.3-32.9c7-18.7 24.9-31.1 44.9-31.1h125.5c20 0 37.9 12.4 44.9 31.1L376 96h88c26.5 0 48 21.5 48 48zM376 288c0-66.2-53.8-120-120-120s-120 53.8-120 120 53.8 120 120 120 120-53.8 120-120zm-32 0c0 48.5-39.5 88-88 88s-88-39.5-88-88 39.5-88 88-88 88 39.5 88 88z"
              />
            </svg>
          </button>
        </>
      )}
    </div>
  );
}

export default SelfieCapture;
