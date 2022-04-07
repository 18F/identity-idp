import {
  forwardRef,
  useRef,
  useState,
  useEffect,
  useCallback,
  useContext,
  useMemo,
  useImperativeHandle,
} from 'react';
import { Icon } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import { useIfStillMounted } from '@18f/identity-react-hooks';
import FileImage from './file-image';
import useInstanceId from '../hooks/use-instance-id';
import useFocusFallbackRef from '../hooks/use-focus-fallback-ref';
import AppContext from '../context/app';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef SelfieCaptureProps
 *
 * @prop {Blob|string|null|undefined} value Current value.
 * @prop {(nextValue:Blob|string|null)=>void} onChange Change handler.
 * @prop {ReactNode=} errorMessage Error to show.
 * @prop {string=} className Optional additional class names to apply to wrapper element.
 */

/**
 * @param {SelfieCaptureProps} props Props object.
 */
function SelfieCapture({ value, onChange, errorMessage, className }, ref) {
  const instanceId = useInstanceId();
  const { t, formatHTML } = useI18n();
  const labelRef = useRef(/** @type {HTMLDivElement?} */ (null));
  const wrapperRef = useRef(/** @type {HTMLDivElement?} */ (null));
  const hadValue = useRef(false);
  const isUpdated = useMemo(() => {
    const nextIsUpdated = Boolean(value && hadValue.current);
    hadValue.current = hadValue.current || Boolean(value);
    return nextIsUpdated;
  }, [value]);
  const retryButtonRef = useFocusFallbackRef(labelRef);
  const captureButtonRef = useFocusFallbackRef(labelRef);
  useImperativeHandle(ref, () => labelRef.current);

  const videoRef = useRef(/** @type {HTMLVideoElement?} */ (null));
  const setVideoRef = useCallback((nextVideoRef) => {
    // React will call an assigned `ref` callback with `null` at the time the element is being
    // removed, which is an opportunity to stop any in-progress capture.
    if (!nextVideoRef && videoRef.current?.srcObject instanceof window.MediaStream) {
      videoRef.current.srcObject.getTracks().forEach((track) => track.stop());
    }

    videoRef.current = nextVideoRef;
  }, []);

  const [isAccessRejected, setIsAccessRejected] = useState(false);
  const [isCapturing, setIsCapturing] = useState(false);
  // Sync capturing state with the availability of a value. If a value is assigned while capture is
  // in progress, reset state. Most often, this is a direct result of calling `onChange` with the
  // next value.
  useMemo(() => setIsCapturing(isCapturing && !value), [value]);

  const ifStillMounted = useIfStillMounted();

  function startCapture() {
    navigator.mediaDevices
      .getUserMedia({ video: { width: 1920, height: 1080 } })
      .then(
        ifStillMounted((/** @type {MediaStream} */ stream) => {
          if (!videoRef.current) {
            return;
          }

          videoRef.current.srcObject = stream;
          videoRef.current.play();
          setIsCapturing(true);
          setIsAccessRejected(false);
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
  }

  useEffect(() => {
    // Start capturing only if not already capturing, and if value has yet to be assigned.
    if (value || isCapturing || !navigator.permissions) {
      return;
    }

    // Type-casting necessary due to: https://github.com/microsoft/TypeScript/issues/33923
    navigator.permissions.query({ name: /** @type {PermissionName} */ ('camera') }).then(
      ifStillMounted((/** @type {PermissionStatus} */ result) => {
        if (result.state === 'granted') {
          startCapture();
        } else if (result.state === 'denied') {
          setIsAccessRejected(true);
        }
      }),
    );
  }, [value]);

  function onCapture() {
    if (!videoRef.current || !wrapperRef.current) {
      return;
    }

    const canvas = document.createElement('canvas');
    const { videoWidth, videoHeight } = videoRef.current;
    const { clientWidth, clientHeight } = wrapperRef.current;

    const height = Math.min(videoHeight, 720);
    const aspectRatio = clientWidth / clientHeight;
    const width = height * aspectRatio;

    const sourceX = (videoWidth - width) / 2;

    canvas.height = height;
    canvas.width = width;

    canvas
      .getContext('2d')
      ?.drawImage(videoRef.current, sourceX, 0, width, height, 0, 0, width, height);

    onChange(canvas.toDataURL('image/jpeg', 0.8));
  }

  let shownErrorMessage;
  if (isAccessRejected) {
    shownErrorMessage = t('doc_auth.errors.camera.blocked');
  } else if (errorMessage) {
    shownErrorMessage = errorMessage;
  }

  const classes = [
    'selfie-capture',
    isCapturing && 'selfie-capture--capturing',
    shownErrorMessage && 'selfie-capture--error',
    isUpdated && !shownErrorMessage && 'selfie-capture--updated',
    value && 'selfie-capture--has-value',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  const labelId = `selfie-capture-label-${instanceId}`;

  const { appName } = useContext(AppContext);

  return (
    <>
      <div
        ref={labelRef}
        id={labelId}
        tabIndex={-1}
        className={['selfie-capture__label', 'usa-label', shownErrorMessage && 'usa-label--error']
          .filter(Boolean)
          .join(' ')}
      >
        {t('doc_auth.headings.document_capture_selfie')}
      </div>
      {shownErrorMessage && (
        <span className="usa-error-message" role="alert">
          {shownErrorMessage}
        </span>
      )}
      {isUpdated && !shownErrorMessage && (
        <span className="usa-success-message" role="alert">
          {t('doc_auth.info.image_updated')}
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
            {value instanceof window.Blob ? (
              <FileImage
                file={value}
                alt={t('doc_auth.accessible_labels.selfie_alt_text')}
                className="selfie-capture__preview-image"
              />
            ) : (
              <img
                src={value}
                alt={t('doc_auth.accessible_labels.selfie_alt_text')}
                className="selfie-capture__preview-image"
              />
            )}
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
              <>
                <div className="selfie-capture__consent-prompt">
                  <strong className="selfie-capture__consent-prompt-banner usa-file-input__banner-text">
                    {t('doc_auth.instructions.document_capture_selfie_consent_banner', {
                      app_name: appName,
                    })}
                  </strong>
                  {isAccessRejected ? (
                    <>
                      <p>
                        {t('doc_auth.instructions.document_capture_selfie_consent_blocked', {
                          app_name: appName,
                        })}
                      </p>
                      <p>
                        {t('doc_auth.instructions.document_capture_selfie_consent_blocked_action', {
                          app_name: appName,
                        })}
                      </p>
                    </>
                  ) : (
                    <p>
                      {formatHTML(
                        t('doc_auth.instructions.document_capture_selfie_consent_action'),
                        {
                          'lg-underline': ({ children }) => (
                            <button
                              type="button"
                              onClick={startCapture}
                              className="usa-button--unstyled"
                            >
                              {children}
                            </button>
                          ),
                        },
                      )}
                    </p>
                  )}
                </div>
                {/* Disable reason: This button is hidden from assistive technology */}
                {/* eslint-disable-next-line jsx-a11y/control-has-associated-label */}
                <button
                  type="button"
                  tabIndex={-1}
                  onClick={startCapture}
                  aria-hidden
                  className="selfie-capture__consent-overlay-button"
                />
              </>
            )}
          </>
        )}
      </div>
    </>
  );
}

export default forwardRef(SelfieCapture);
