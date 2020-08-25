import React, { useRef, useState, useEffect, useCallback, useMemo } from 'react';
import { Icon } from '@18f/identity-components';
import FileImage from './file-image';
import useIfStillMounted from '../hooks/use-if-still-mounted';
import useI18n from '../hooks/use-i18n';
import useInstanceId from '../hooks/use-instance-id';
import useFocusFallbackRef from '../hooks/use-focus-fallback-ref';

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
  const instanceId = useInstanceId();
  const { t } = useI18n();
  const labelRef = useRef(/** @type {HTMLDivElement?} */ (null));
  const wrapperRef = useRef(/** @type {HTMLDivElement?} */ (null));
  const retryButtonRef = useFocusFallbackRef(labelRef);
  const captureButtonRef = useFocusFallbackRef(labelRef);

  const videoRef = useRef(/** @type {HTMLVideoElement?} */ (null));
  const setVideoRef = useCallback((ref) => {
    // React will call an assigned `ref` callback with `null` at the time the element is being
    // removed, which is an opportunity to stop any in-progress capture.
    if (!ref && videoRef.current && videoRef.current.srcObject instanceof window.MediaStream) {
      videoRef.current.srcObject.getTracks().forEach((track) => track.stop());
    }

    videoRef.current = ref;
  }, []);

  const [isAccessRejected, setIsAccessRejected] = useState(false);
  const [isCapturing, setIsCapturing] = useState(false);
  // Sync capturing state with the availability of a value. If a value is assigned while capture is
  // in progress, reset state. Most often, this is a direct result of calling `onChange` with the
  // next value.
  useMemo(() => setIsCapturing(isCapturing && !value), [value]);

  const ifStillMounted = useIfStillMounted();

  useEffect(() => {
    // Start capturing only if not already capturing, and if value has yet to be assigned.
    if (value || isCapturing) {
      return;
    }

    navigator.mediaDevices
      .getUserMedia({ video: true })
      .then(
        ifStillMounted((/** @type {MediaStream} */ stream) => {
          if (!videoRef.current) {
            return;
          }

          videoRef.current.srcObject = stream;
          videoRef.current.play();
          setIsCapturing(true);
        }),
      )
      .catch(
        ifStillMounted((error) => {
          if (error.name !== 'NotAllowedError') {
            throw error;
          }

          setIsAccessRejected(true);
        }),
      );
  }, [value]);

  function onCapture() {
    if (!videoRef.current || !wrapperRef.current) {
      return;
    }

    const canvas = document.createElement('canvas');
    const { videoWidth, videoHeight } = videoRef.current;
    const { clientWidth: width, clientHeight: height } = wrapperRef.current;

    // The capture is shown as a square, even if the video input aspect ratio is not square. To
    // ensure that the captured image matches what is shown to the user, offset the source to X
    // corresponding with centered squared height.
    const downsizeRatio = height / videoHeight;
    const sourceX = (videoWidth - width / downsizeRatio) / 2;

    canvas.height = height;
    canvas.width = width;

    canvas
      .getContext('2d')
      ?.drawImage(
        videoRef.current,
        sourceX,
        0,
        width / downsizeRatio,
        height / downsizeRatio,
        0,
        0,
        width,
        height,
      );
    canvas.toBlob(ifStillMounted(onChange));
  }

  const classes = [
    'selfie-capture',
    isCapturing && 'selfie-capture--capturing',
    isAccessRejected && 'selfie-capture--access-rejected',
    value && 'selfie-capture--has-value',
  ]
    .filter(Boolean)
    .join(' ');

  const labelId = `selfie-capture-label-${instanceId}`;

  return (
    <>
      <div
        ref={labelRef}
        id={labelId}
        tabIndex={-1}
        className={['selfie-capture__label', 'usa-label', isAccessRejected && 'usa-label--error']
          .filter(Boolean)
          .join(' ')}
      >
        {t('doc_auth.headings.document_capture_selfie')}
      </div>
      {isAccessRejected && (
        <span className="usa-error-message" role="alert">
          {t('errors.doc_auth.document_capture_selfie_consent_blocked')}
        </span>
      )}
      <div ref={wrapperRef} className={classes}>
        {value ? (
          <>
            <div className="selfie-capture__preview-heading usa-file-input__preview-heading">
              <span />
              <button
                ref={retryButtonRef}
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
            <video ref={setVideoRef} className="selfie-capture__video" aria-labelledby={labelId} />
            {isCapturing ? (
              <>
                <div className="selfie-capture__frame">
                  <div className="selfie-capture__frame-corner" />
                  <div className="selfie-capture__frame-corner" />
                  <div className="selfie-capture__frame-corner" />
                  <div className="selfie-capture__frame-corner" />
                </div>
                <button
                  ref={captureButtonRef}
                  type="button"
                  className="usa-button selfie-capture__capture"
                  aria-label={t('doc_auth.buttons.take_picture')}
                  onClick={onCapture}
                >
                  <Icon.Camera className="selfie-capture__capture-icon" />
                </button>
              </>
            ) : (
              <div className="selfie-capture__consent-prompt">
                <strong className="selfie-capture__consent-prompt-banner usa-file-input__banner-text">
                  {t('doc_auth.instructions.document_capture_selfie_consent_banner')}
                </strong>
                <p>{t('doc_auth.instructions.document_capture_selfie_consent_reason')}</p>
                {isAccessRejected && (
                  <p>{t('doc_auth.instructions.document_capture_selfie_consent_blocked')}</p>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </>
  );
}

export default SelfieCapture;
