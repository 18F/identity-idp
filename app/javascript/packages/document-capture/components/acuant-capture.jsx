import React, {
  forwardRef,
  useContext,
  useRef,
  useState,
  useMemo,
  useEffect,
  useImperativeHandle,
} from 'react';
import AcuantContext from '../context/acuant';
import AcuantCaptureCanvas from './acuant-capture-canvas';
import FileInput from './file-input';
import FullScreen from './full-screen';
import Button from './button';
import useI18n from '../hooks/use-i18n';
import DeviceContext from '../context/device';
import FileBase64CacheContext from '../context/file-base64-cache';
import UploadContext from '../context/upload';
import useIfStillMounted from '../hooks/use-if-still-mounted';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef AcuantPassiveLiveness
 *
 * @prop {(callback:(nextImageData:string)=>void)=>void} startSelfieCapture Start liveness capture.
 */

/**
 * @typedef AcuantGlobals
 *
 * @prop {AcuantPassiveLiveness} AcuantPassiveLiveness Acuant Passive Liveness API.
 */

/**
 * @typedef {typeof window & AcuantGlobals} AcuantGlobal
 */

/**
 * @typedef AcuantCaptureProps
 *
 * @prop {string} label Label associated with file input.
 * @prop {string=} bannerText Optional banner text to show in file input.
 * @prop {Blob?=} value Current value.
 * @prop {(nextValue:Blob?)=>void} onChange Callback receiving next value on change.
 * @prop {'user'=} capture Facing mode of capture. If capture is not specified and a camera is
 * supported, defaults to the Acuant environment camera capture.
 * @prop {string=} className Optional additional class names.
 * @prop {boolean=} allowUpload Whether to allow file upload. Defaults to `true`.
 * @prop {ReactNode=} errorMessage Error to show.
 */

/**
 * The minimum glare score value to be considered acceptable.
 *
 * @type {number}
 */
const ACCEPTABLE_GLARE_SCORE = 50;

/**
 * The minimum sharpness score value to be considered acceptable.
 *
 * @type {number}
 */
const ACCEPTABLE_SHARPNESS_SCORE = 50;

/**
 * Returns an instance of File representing the given data URL.
 *
 * @param {string} dataURL Data URL.
 *
 * @return {Blob} File representation.
 */
function toBlob(dataURL) {
  const [header, data] = dataURL.split(',');
  const isBase64 = /;base64$/.test(header);
  const [type] = header.replace(/^data:/, '').split(';');
  const decodedData = isBase64 ? window.atob(data) : decodeURIComponent(data);

  const view = Uint8Array.from(decodedData, (chunk) => chunk.charCodeAt(0));
  return new window.Blob([view], { type });
}

/**
 * Returns an element serving as an enhanced FileInput, supporting direct capture using Acuant SDK
 * in supported devices.
 *
 * @param {AcuantCaptureProps} props Props object.
 */
function AcuantCapture(
  {
    label,
    bannerText,
    value,
    onChange = () => {},
    capture,
    className,
    allowUpload = true,
    errorMessage,
  },
  ref,
) {
  const fileCache = useContext(FileBase64CacheContext);
  const { isReady, isError, isCameraSupported } = useContext(AcuantContext);
  const { isMockClient } = useContext(UploadContext);
  const inputRef = useRef(/** @type {?HTMLInputElement} */ (null));
  const isForceUploading = useRef(false);
  const [isCapturingEnvironment, setIsCapturingEnvironment] = useState(false);
  const [ownErrorMessage, setOwnErrorMessage] = useState(/** @type {?string} */ (null));
  const ifStillMounted = useIfStillMounted();
  useMemo(() => setOwnErrorMessage(null), [value]);
  const { isMobile } = useContext(DeviceContext);
  const { t, formatHTML } = useI18n();
  const hasCapture = !isError && (isReady ? isCameraSupported : isMobile);
  useEffect(() => {
    // If capture had started before Acuant was ready, stop capture if readiness reveals that no
    // capture is supported. This takes advantage of the fact that state setter is noop if value of
    // `isCapturing` is already false.
    if (!hasCapture) {
      setIsCapturingEnvironment(false);
    }
  }, [hasCapture]);
  useImperativeHandle(ref, () => inputRef.current);

  /**
   * Calls onChange with next value and resets any errors which may be present.
   *
   * @param {Blob?} nextValue Next value.
   */
  function onChangeAndResetError(nextValue) {
    setOwnErrorMessage(null);
    onChange(nextValue);
  }

  /**
   * Responds to a click by starting capture if supported in the environment, or triggering the
   * default file picker prompt. The click event may originate from the file input itself, or
   * another element which aims to trigger the prompt of the file input.
   *
   * @param {import('react').MouseEvent} event Click event.
   */
  function startCaptureOrTriggerUpload(event) {
    if (event.target === inputRef.current) {
      const shouldStartEnvironmentCapture =
        hasCapture && capture !== 'user' && !isForceUploading.current;

      if (!allowUpload || capture === 'user' || shouldStartEnvironmentCapture) {
        event.preventDefault();
      }

      if (capture === 'user') {
        /** @type {AcuantGlobal} */ (window).AcuantPassiveLiveness.startSelfieCapture(
          ifStillMounted((nextImageData) => {
            const dataAsBlob = toBlob(`data:image/jpeg;base64,${nextImageData}`);
            onChangeAndResetError(dataAsBlob);
          }),
        );
      } else if (shouldStartEnvironmentCapture) {
        setIsCapturingEnvironment(true);
      }

      isForceUploading.current = false;
    } else {
      inputRef.current?.click();
    }
  }

  /**
   * Triggers upload to occur, regardless of support for direct capture. This is necessary since the
   * default behavior for interacting with the file input is intercepted when capture is supported.
   * Calling `forceUpload` will flag the click handling to skip intercepting the event as capture.
   */
  function forceUpload() {
    if (!inputRef.current) {
      return;
    }

    isForceUploading.current = true;

    const originalCapture = inputRef.current.getAttribute('capture');

    if (originalCapture !== null) {
      inputRef.current.removeAttribute('capture');
    }

    inputRef.current.click();

    if (originalCapture !== null) {
      inputRef.current.setAttribute('capture', originalCapture);
    }
  }

  return (
    <div className={className}>
      {isCapturingEnvironment && (
        <FullScreen onRequestClose={() => setIsCapturingEnvironment(false)}>
          <AcuantCaptureCanvas
            onImageCaptureSuccess={(nextCapture) => {
              if (nextCapture.glare < ACCEPTABLE_GLARE_SCORE) {
                setOwnErrorMessage(t('errors.doc_auth.photo_glare'));
              } else if (nextCapture.sharpness < ACCEPTABLE_SHARPNESS_SCORE) {
                setOwnErrorMessage(t('errors.doc_auth.photo_blurry'));
              } else {
                const dataAsBlob = toBlob(nextCapture.image.data);
                fileCache.set(dataAsBlob, nextCapture.image.data);
                onChangeAndResetError(dataAsBlob);
              }

              setIsCapturingEnvironment(false);
            }}
            onImageCaptureFailure={() => {
              setOwnErrorMessage(t('errors.doc_auth.capture_failure'));
              setIsCapturingEnvironment(false);
            }}
          />
        </FullScreen>
      )}
      <FileInput
        ref={inputRef}
        label={label}
        hint={hasCapture || !allowUpload ? undefined : t('doc_auth.tips.document_capture_hint')}
        bannerText={bannerText}
        accept={isMockClient ? undefined : ['image/*']}
        capture={capture}
        value={value}
        errorMessage={ownErrorMessage ?? errorMessage}
        onClick={startCaptureOrTriggerUpload}
        onChange={onChangeAndResetError}
        onError={() => setOwnErrorMessage(null)}
      />
      <div className="margin-top-2">
        {isMobile && (
          <Button
            isSecondary={!value}
            isUnstyled={!!value}
            onClick={startCaptureOrTriggerUpload}
            className={value ? 'margin-right-1' : 'margin-right-2'}
          >
            {(hasCapture || !allowUpload) &&
              (value
                ? t('doc_auth.buttons.take_picture_retry')
                : t('doc_auth.buttons.take_picture'))}
            {!hasCapture && allowUpload && t('doc_auth.buttons.upload_picture')}
          </Button>
        )}
        {isMobile &&
          hasCapture &&
          allowUpload &&
          formatHTML(t('doc_auth.buttons.take_or_upload_picture'), {
            'lg-take-photo': () => null,
            'lg-upload': ({ children }) => (
              <Button isUnstyled onClick={forceUpload} className="margin-left-1">
                {children}
              </Button>
            ),
          })}
      </div>
    </div>
  );
}

export default forwardRef(AcuantCapture);
