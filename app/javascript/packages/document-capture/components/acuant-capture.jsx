import {
  forwardRef,
  useContext,
  useRef,
  useState,
  useMemo,
  useEffect,
  useImperativeHandle,
} from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { useIfStillMounted, useDidUpdateEffect } from '@18f/identity-react-hooks';
import { Button } from '@18f/identity-components';
import AnalyticsContext from '../context/analytics';
import AcuantContext from '../context/acuant';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';
import AcuantCamera from './acuant-camera';
import AcuantCaptureCanvas from './acuant-capture-canvas';
import FileInput from './file-input';
import FullScreen from './full-screen';
import DeviceContext from '../context/device';
import UploadContext from '../context/upload';
import useCounter from '../hooks/use-counter';
import useCookie from '../hooks/use-cookie';

/** @typedef {import('react').ReactNode} ReactNode */
/** @typedef {import('./acuant-camera').AcuantSuccessResponse} AcuantSuccessResponse */
/** @typedef {import('./acuant-camera').AcuantDocumentType} AcuantDocumentType */
/** @typedef {import('./full-screen').FullScreenRefHandle} FullScreenRefHandle */
/** @typedef {import('../context/acuant').AcuantGlobal} AcuantGlobal */

/**
 * @typedef {"id"|"passport"|"none"} AcuantDocumentTypeLabel
 */

/**
 * @typedef {"success"|"glare"|"blurry"} AcuantImageAssessment
 */

/**
 * @typedef {"acuant"|"upload"} ImageSource
 */

/**
 * @typedef ImageAnalyticsPayload
 *
 * @prop {number?} width Image width, or null if unknown.
 * @prop {number?} height Image height, or null if unknown.
 * @prop {string?} mimeType Mime type, or null if unknown.
 * @prop {ImageSource} source Method by which image was added.
 * @prop {number=} attempt Total number of attempts at this point.
 * @prop {number} size Size of image, in bytes.
 */

/**
 * @typedef _AcuantImageAnalyticsPayload
 *
 * @prop {AcuantDocumentTypeLabel} documentType
 * @prop {number} dpi
 * @prop {number} moire
 * @prop {number} glare
 * @prop {number} glareScoreThreshold
 * @prop {boolean} isAssessedAsGlare
 * @prop {number} sharpness
 * @prop {number} sharpnessScoreThreshold
 * @prop {boolean} isAssessedAsBlurry
 * @prop {AcuantImageAssessment} assessment
 */

/**
 * @typedef {ImageAnalyticsPayload & _AcuantImageAnalyticsPayload} AcuantImageAnalyticsPayload
 */

/**
 * @typedef AcuantCaptureProps
 *
 * @prop {string} label Label associated with file input.
 * @prop {string=} bannerText Optional banner text to show in file input.
 * @prop {string|Blob|null|undefined} value Current value.
 * @prop {(
 *   nextValue: string|Blob|null,
 *   metadata?: ImageAnalyticsPayload
 * )=>void} onChange Callback receiving next value on change.
 * @prop {()=>void=} onCameraAccessDeclined Camera permission declined callback.
 * @prop {'user'|'environment'=} capture Facing mode of capture. If capture is not specified and a
 * camera is supported, defaults to the Acuant environment camera capture.
 * @prop {string=} className Optional additional class names.
 * @prop {boolean=} allowUpload Whether to allow file upload. Defaults to `true`.
 * @prop {ReactNode=} errorMessage Error to show.
 * @prop {string} name Prefix to prepend to user action analytics labels.
 */

/**
 * Non-breaking space (`&nbsp;`) represented as unicode escape sequence, which React will more
 * happily tolerate than an HTML entity.
 *
 * @type {string}
 */
const NBSP_UNICODE = '\u00A0';

/**
 * A noop function.
 */
const noop = () => {};

/**
 * Returns true if the given Acuant capture failure was caused by the user declining access to the
 * camera, or false otherwise.
 *
 * @param {import('./acuant-camera').AcuantCaptureFailureError} error
 *
 * @return {boolean}
 */
export const isAcuantCameraAccessFailure = (error) => error instanceof Error;

/**
 * Returns a human-readable document label corresponding to the given document type constant.
 *
 * @param {AcuantDocumentType} documentType
 *
 * @return {AcuantDocumentTypeLabel} Human-readable document label.
 */
function getDocumentTypeLabel(documentType) {
  switch (documentType) {
    case 1:
      return 'id';
    case 2:
      return 'passport';
    default:
      return 'none';
  }
}

/**
 * @param {import('./acuant-camera').AcuantCaptureFailureError} error
 * @param {string=} code
 *
 * @return {string}
 */
export function getNormalizedAcuantCaptureFailureMessage(error, code) {
  if (isAcuantCameraAccessFailure(error)) {
    return 'User or system denied camera access';
  }

  const { REPEAT_FAIL_CODE, SEQUENCE_BREAK_CODE } = /** @type {AcuantGlobal} */ (window)
    .AcuantJavascriptWebSdk;

  switch (code) {
    case REPEAT_FAIL_CODE:
      return 'Capture started after failure already occurred (REPEAT_FAIL_CODE)';
    case SEQUENCE_BREAK_CODE:
      return 'iOS 15 GPU Highwater failure (SEQUENCE_BREAK_CODE)';
    default:
  }

  if (!error) {
    return 'Cropping failure';
  }

  switch (error) {
    case 'Camera not supported.':
      return 'Camera not supported';
    case 'Missing HTML elements.':
    case "Expected div with 'acuant-camera' id":
      return 'Required page elements are not available';
    case 'already started.':
      return 'Capture already started';
    default:
      return 'Unknown error';
  }
}

/**
 * @param {File} file Image file.
 *
 * @return {Promise<{width: number?, height: number?}>}
 */
function getImageDimensions(file) {
  let objectURL;
  return file.type.indexOf('image/') === 0
    ? new Promise((resolve) => {
        objectURL = window.URL.createObjectURL(file);
        const image = new window.Image();
        image.onload = () => resolve({ width: image.width, height: image.height });
        image.onerror = () => resolve({ width: null, height: null });
        image.src = objectURL;
      })
        .then(({ width, height }) => {
          window.URL.revokeObjectURL(objectURL);
          return { width, height };
        })
        .catch(() => ({ width: null, height: null }))
    : Promise.resolve({ width: null, height: null });
}

/**
 * Pauses default focus trap behaviors for a single tick. If a focus transition occurs during this
 * tick, the focus trap's deactivation will be overridden to prevent any default focus return, in
 * order to avoid a race condition between the intended focus targets.
 *
 * @param {import('focus-trap').FocusTrap} focusTrap
 */
function suspendFocusTrapForAnticipatedFocus(focusTrap) {
  // Pause trap event listeners to prevent focus from being pulled back into the trap container in
  // response to programmatic focus transitions.
  focusTrap.pause();

  const originalFocus = document.activeElement;

  // If an element is focused while behaviors are suspended, prevent the default deactivate from
  // attempting to return focus to any other element.
  const originalDeactivate = focusTrap.deactivate;
  focusTrap.deactivate = (deactivateOptions) => {
    const didChangeFocus = originalFocus !== document.activeElement;
    if (didChangeFocus) {
      deactivateOptions = { ...deactivateOptions, returnFocus: false };
    }

    return originalDeactivate(deactivateOptions);
  };

  // After the current frame, assume that focus was not moved elsewhere, or at least resume original
  // trap behaviors.
  setTimeout(() => {
    focusTrap.deactivate = originalDeactivate;
    focusTrap.unpause();
  }, 0);
}

export function getDecodedBase64ByteSize(data) {
  let bytes = 0.75 * data.length;

  let i = data.length;
  while (data[--i] === '=') {
    bytes--;
  }

  return bytes;
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
    onCameraAccessDeclined = () => {},
    capture,
    className,
    allowUpload = true,
    errorMessage,
    name,
  },
  ref,
) {
  const {
    isReady,
    isActive: isAcuantInstanceActive,
    isAcuantLoaded,
    isError,
    isCameraSupported,
    glareThreshold,
    sharpnessThreshold,
  } = useContext(AcuantContext);
  const { isMockClient } = useContext(UploadContext);
  const { addPageAction } = useContext(AnalyticsContext);
  const fullScreenRef = useRef(/** @type {FullScreenRefHandle?} */ (null));
  const inputRef = useRef(/** @type {?HTMLInputElement} */ (null));
  const isForceUploading = useRef(false);
  const isSuppressingClickLogging = useRef(false);
  const [isCapturingEnvironment, setIsCapturingEnvironment] = useState(false);
  const [ownErrorMessage, setOwnErrorMessage] = useState(/** @type {?string} */ (null));
  const [hasStartedCropping, setHasStartedCropping] = useState(false);
  const ifStillMounted = useIfStillMounted();
  useMemo(() => setOwnErrorMessage(null), [value]);
  const { isMobile } = useContext(DeviceContext);
  const { t, formatHTML } = useI18n();
  const [attempt, incrementAttempt] = useCounter(1);
  const [acuantFailureCookie, setAcuantFailureCookie, refreshAcuantFailureCookie] =
    useCookie('AcuantCameraHasFailed');
  const { onFailedCaptureAttempt, onResetFailedCaptureAttempts } = useContext(
    FailedCaptureAttemptsContext,
  );
  const hasCapture = !isError && (isReady ? isCameraSupported : isMobile);
  useEffect(() => {
    // If capture had started before Acuant was ready, stop capture if readiness reveals that no
    // capture is supported. This takes advantage of the fact that state setter is noop if value of
    // `isCapturing` is already false.
    if (!hasCapture) {
      setIsCapturingEnvironment(false);
    }
  }, [hasCapture]);
  useDidUpdateEffect(() => setHasStartedCropping(false), [isCapturingEnvironment]);
  useImperativeHandle(ref, () => inputRef.current);

  /**
   * Calls onChange with next value and resets any errors which may be present.
   *
   * @param {Blob|string|null} nextValue Next value.
   * @param {ImageAnalyticsPayload=} metadata Capture metadata.
   */
  function onChangeAndResetError(nextValue, metadata) {
    setOwnErrorMessage(null);
    onChange(nextValue, metadata);
  }

  /**
   * Returns an analytics payload, decorated with common values.
   *
   * @template {ImageAnalyticsPayload|AcuantImageAnalyticsPayload} P
   *
   * @param {P} payload
   *
   * @return {P}
   */
  function getAddAttemptAnalyticsPayload(payload) {
    const enhancedPayload = { ...payload, attempt };
    incrementAttempt();
    return enhancedPayload;
  }

  /**
   * Handler for file input change events.
   *
   * @param {File?} nextValue Next value, if set.
   */
  async function onUpload(nextValue) {
    /** @type {ImageAnalyticsPayload=} */
    let analyticsPayload;
    if (nextValue) {
      const { width, height } = await getImageDimensions(nextValue);

      analyticsPayload = getAddAttemptAnalyticsPayload({
        width,
        height,
        mimeType: nextValue.type,
        source: 'upload',
        size: nextValue.size,
      });

      addPageAction({
        label: `IdV: ${name} image added`,
        payload: analyticsPayload,
      });
    }

    onChangeAndResetError(nextValue, analyticsPayload);
  }

  /**
   * Given a click source, returns a higher-order function that, when called, will log an event
   * before calling the original function.
   *
   * @template {(...args: any[]) => any} T
   *
   * @param {string} source Click source.
   * @param {{isDrop: boolean}=} metadata Additional payload metadata to log.
   *
   * @return {(fn: T) => (...args: Parameters<T>) => ReturnType<T>}
   */
  function withLoggedClick(source, metadata = { isDrop: false }) {
    return (fn) =>
      (...args) => {
        if (!isSuppressingClickLogging.current) {
          addPageAction({
            label: `IdV: ${name} image clicked`,
            payload: { source, ...metadata },
          });
        }

        return fn(...args);
      };
  }

  /**
   * Calls the given function, during which time any normal click logging will be suppressed.
   *
   * @param {() => any} fn Function to call
   */
  function withoutClickLogging(fn) {
    isSuppressingClickLogging.current = true;
    fn();
    isSuppressingClickLogging.current = false;
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
      const isAcuantCaptureCapable = hasCapture && !acuantFailureCookie;
      const shouldStartAcuantCapture =
        isAcuantCaptureCapable && capture !== 'user' && !isForceUploading.current;
      const shouldStartSelfieCapture =
        isAcuantLoaded && capture === 'user' && !isForceUploading.current;

      if (!allowUpload || shouldStartSelfieCapture || shouldStartAcuantCapture) {
        event.preventDefault();
      }

      if (shouldStartSelfieCapture) {
        /** @type {AcuantGlobal} */ (window).AcuantPassiveLiveness.startSelfieCapture(
          ifStillMounted((nextImageData) => {
            const dataURI = `data:image/jpeg;base64,${nextImageData}`;
            onChangeAndResetError(dataURI);
          }),
        );
      } else if (shouldStartAcuantCapture && !isAcuantInstanceActive) {
        setIsCapturingEnvironment(true);
      }

      isForceUploading.current = false;
    } else {
      withoutClickLogging(() => inputRef.current?.click());
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

    withoutClickLogging(() => inputRef.current?.click());

    if (originalCapture !== null) {
      inputRef.current.setAttribute('capture', originalCapture);
    }
  }

  /**
   * @param {AcuantSuccessResponse} nextCapture
   */
  function onAcuantImageCaptureSuccess(nextCapture) {
    const { image, cardType, dpi, moire, glare, sharpness } = nextCapture;
    const isAssessedAsGlare = glare < glareThreshold;
    const isAssessedAsBlurry = sharpness < sharpnessThreshold;
    const { width, height, data } = image;

    /** @type {AcuantImageAssessment} */
    let assessment;
    if (isAssessedAsGlare) {
      setOwnErrorMessage(t('doc_auth.errors.glare.failed_short'));
      assessment = 'glare';
    } else if (isAssessedAsBlurry) {
      setOwnErrorMessage(t('doc_auth.errors.sharpness.failed_short'));
      assessment = 'blurry';
    } else {
      assessment = 'success';
    }

    /** @type {AcuantImageAnalyticsPayload} */
    const analyticsPayload = getAddAttemptAnalyticsPayload({
      width,
      height,
      mimeType: 'image/jpeg', // Acuant Web SDK currently encodes all images as JPEG
      source: 'acuant',
      documentType: getDocumentTypeLabel(cardType),
      dpi,
      moire,
      glare,
      glareScoreThreshold: glareThreshold,
      isAssessedAsGlare,
      sharpness,
      sharpnessScoreThreshold: sharpnessThreshold,
      isAssessedAsBlurry,
      assessment,
      size: getDecodedBase64ByteSize(nextCapture.image.data),
    });

    addPageAction({
      key: 'documentCapture.acuantWebSDKResult',
      label: `IdV: ${name} image added`,
      payload: analyticsPayload,
    });

    if (assessment === 'success') {
      onChangeAndResetError(data, analyticsPayload);
      onResetFailedCaptureAttempts();
    } else {
      onFailedCaptureAttempt({ isAssessedAsGlare, isAssessedAsBlurry });
    }

    setIsCapturingEnvironment(false);
  }

  return (
    <div className={[className, 'document-capture-acuant-capture'].filter(Boolean).join(' ')}>
      {isCapturingEnvironment && (
        <AcuantCamera
          onCropStart={() => setHasStartedCropping(true)}
          onImageCaptureSuccess={onAcuantImageCaptureSuccess}
          onImageCaptureFailure={(error, code) => {
            const { SEQUENCE_BREAK_CODE } = /** @type {AcuantGlobal} */ (window)
              .AcuantJavascriptWebSdk;
            if (isAcuantCameraAccessFailure(error)) {
              if (fullScreenRef.current?.focusTrap) {
                suspendFocusTrapForAnticipatedFocus(fullScreenRef.current.focusTrap);
              }

              // Internally, Acuant sets a cookie to bail on guided capture if initialization had
              // previously failed for any reason, including declined permission. Since the cookie
              // never expires, and since we want to re-prompt even if the user had previously
              // declined, unset the cookie value when failure occurs for permissions.
              setAcuantFailureCookie(null);

              onCameraAccessDeclined();
            } else if (code === SEQUENCE_BREAK_CODE) {
              setOwnErrorMessage(
                `${t('doc_auth.errors.upload_error')} ${t('errors.messages.try_again')
                  .split(' ')
                  .join(NBSP_UNICODE)}`,
              );

              refreshAcuantFailureCookie();
            } else {
              setOwnErrorMessage(t('doc_auth.errors.camera.failed'));
            }

            setIsCapturingEnvironment(false);
            addPageAction({
              label: 'IdV: Image capture failed',
              payload: {
                field: name,
                error: getNormalizedAcuantCaptureFailureMessage(error, code),
              },
            });
          }}
        >
          {!hasStartedCropping && (
            <FullScreen
              ref={fullScreenRef}
              label={t('doc_auth.accessible_labels.document_capture_dialog')}
              onRequestClose={() => setIsCapturingEnvironment(false)}
            >
              <AcuantCaptureCanvas />
            </FullScreen>
          )}
        </AcuantCamera>
      )}
      <FileInput
        ref={inputRef}
        label={label}
        hint={hasCapture || !allowUpload ? undefined : t('doc_auth.tips.document_capture_hint')}
        bannerText={bannerText}
        invalidTypeText={t('doc_auth.errors.file_type.invalid')}
        fileUpdatedText={t('doc_auth.info.image_updated')}
        fileLoadingText={t('doc_auth.info.image_loading')}
        fileLoadedText={t('doc_auth.info.image_loaded')}
        accept={isMockClient ? undefined : ['image/jpeg', 'image/png']}
        capture={capture}
        value={value}
        errorMessage={ownErrorMessage ?? errorMessage}
        isValuePending={hasStartedCropping}
        onClick={withLoggedClick('placeholder')(startCaptureOrTriggerUpload)}
        onDrop={withLoggedClick('placeholder', { isDrop: true })(noop)}
        onChange={onUpload}
        onError={() => setOwnErrorMessage(null)}
      />
      <div className="margin-top-2">
        {isMobile && (
          <Button
            isFlexibleWidth
            isOutline={!value}
            isUnstyled={!!value}
            onClick={withLoggedClick('button')(startCaptureOrTriggerUpload)}
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
              <span className="padding-left-1">
                <Button isUnstyled onClick={withLoggedClick('upload')(forceUpload)}>
                  {children}
                </Button>
              </span>
            ),
          })}
      </div>
    </div>
  );
}

export default forwardRef(AcuantCapture);
