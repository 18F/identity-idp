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
import { Button, FullScreen } from '@18f/identity-components';
import type { FullScreenRefHandle } from '@18f/identity-components';
import type { FocusTrap } from 'focus-trap';
import type { ReactNode, MouseEvent, Ref } from 'react';
import AnalyticsContext from '../context/analytics';
import AcuantContext from '../context/acuant';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';
import AcuantCamera from './acuant-camera';
import AcuantCaptureCanvas from './acuant-capture-canvas';
import FileInput from './file-input';
import DeviceContext from '../context/device';
import UploadContext from '../context/upload';
import useCounter from '../hooks/use-counter';
import useCookie from '../hooks/use-cookie';
import type {
  AcuantSuccessResponse,
  AcuantDocumentType,
  AcuantCaptureFailureError,
} from './acuant-camera';

type AcuantDocumentTypeLabel = 'id' | 'passport' | 'none';
type AcuantImageAssessment = 'success' | 'glare' | 'blurry';
type ImageSource = 'acuant' | 'upload';

interface ImageAnalyticsPayload {
  /**
   * Image width, or null if unknown
   */
  width?: number | null;
  /**
   * Image height, or null if unknown
   */
  height?: number | null;
  /**
   * Mime type, or null if unknown
   */
  mimeType?: string | null;
  /**
   * Method by which the image was added
   */
  source: ImageSource;
  /**
   * Total number of attempts at this point
   */
  attempt?: number;
  /**
   * Size of the image in bytes
   */
  size: number;
}

interface _AcuantImageAnalyticsPayload {
  documentType: AcuantDocumentTypeLabel;
  dpi: number;
  moire: number;
  glare: number;
  glareScoreThreshold: number;
  isAssessedAsGlare: boolean;
  sharpness: number;
  sharpnessScoreThreshold: number;
  isAssessedAsBlurry: boolean;
  assessment: AcuantImageAssessment;
}

type AcuantImageAnalyticsPayload = ImageAnalyticsPayload & _AcuantImageAnalyticsPayload;

interface AcuantCaptureProps {
  /**
   * Label associated with file input
   */
  label: string;
  /**
   * Optional banner text to show in file input
   */
  bannerText: string;
  /**
   * Current value
   */
  value: string | Blob | null | undefined;
  /**
   * Callback receiving next value on change
   */
  onChange: (nextValue: string | Blob | null, metadata?: ImageAnalyticsPayload) => void;
  /**
   * Camera permission declined callback
   */
  onCameraAccessDeclined?: () => void;
  /**
   * Facing mode of caopture. If capture is not
   * specified and a camera is supported, defaults
   * to the Acuant environment camera capture.
   */
  capture: 'user' | 'environment';
  /**
   * Optional additional class names
   */
  className?: string;
  /**
   * Whether to allow file upload. Defaults
   * to true.
   */
  allowUpload?: boolean;
  /**
   * Error message to show
   */
  errorMessage: ReactNode;
  /**
   * Prefix to prepend to user action analytics labels.
   */
  name: string;
}

/**
 * Non-breaking space (`&nbsp;`) represented as unicode escape sequence, which React will more
 * happily tolerate than an HTML entity.
 */
const NBSP_UNICODE = '\u00A0';

/**
 * A noop function.
 */
const noop = () => {};

/**
 * Returns true if the given Acuant capture failure was caused by the user declining access to the
 * camera, or false otherwise.
 */
export const isAcuantCameraAccessFailure = (error: AcuantCaptureFailureError) =>
  error instanceof Error;

/**
 * Returns a human-readable document label corresponding to the given document type constant.
 *
 */
function getDocumentTypeLabel(documentType: AcuantDocumentType): AcuantDocumentTypeLabel {
  switch (documentType) {
    case 1:
      return 'id';
    case 2:
      return 'passport';
    default:
      return 'none';
  }
}

export function getNormalizedAcuantCaptureFailureMessage(
  error: AcuantCaptureFailureError,
  code: string | undefined,
): string {
  if (isAcuantCameraAccessFailure(error)) {
    return 'User or system denied camera access';
  }

  const { REPEAT_FAIL_CODE, SEQUENCE_BREAK_CODE } =
    (window as AcuantGlobal).AcuantJavascriptWebSdk;

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

function getImageDimensions(file: File): Promise<{ width: number | null; height: number | null }> {
  let objectURL: string;
  return file.type.indexOf('image/') === 0
    ? new Promise<{ width: number | null; height: number | null }>((resolve) => {
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
 */
function suspendFocusTrapForAnticipatedFocus(focusTrap: FocusTrap) {
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

export function getDecodedBase64ByteSize(data: string | any[]) {
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
  }: AcuantCaptureProps,
  ref: Ref<HTMLInputElement | null>,
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
  const fullScreenRef = useRef<FullScreenRefHandle>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const isForceUploading = useRef(false);
  const isSuppressingClickLogging = useRef(false);
  const [isCapturingEnvironment, setIsCapturingEnvironment] = useState(false);
  const [ownErrorMessage, setOwnErrorMessage] = useState<string | null>(null);
  const [hasStartedCropping, setHasStartedCropping] = useState(false);
  const ifStillMounted = useIfStillMounted();
  useMemo(() => setOwnErrorMessage(null), [value]);
  const { isMobile } = useContext(DeviceContext);
  const { t, formatHTML } = useI18n();
  const [attempt, incrementAttempt] = useCounter(1);
  const [acuantFailureCookie, setAcuantFailureCookie, refreshAcuantFailureCookie] =
    useCookie('AcuantCameraHasFailed');

  const {
    failedCaptureAttempts,
    onFailedCaptureAttempt,
    onResetFailedCaptureAttempts,
    forceNativeCamera,
  } = useContext(FailedCaptureAttemptsContext);

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
   */
  function onChangeAndResetError(
    nextValue: Blob | string | null,
    metadata?: ImageAnalyticsPayload | undefined,
  ) {
    setOwnErrorMessage(null);
    onChange(nextValue, metadata);
  }

  /**
   * Returns an analytics payload, decorated with common values.
   */
  function getAddAttemptAnalyticsPayload<P>(payload: P): P {
    const enhancedPayload = { ...payload, attempt };
    incrementAttempt();
    return enhancedPayload;
  }

  /**
   * Handler for file input change events.
   */
  async function onUpload(nextValue: File | null) {
    let analyticsPayload: ImageAnalyticsPayload | undefined;
    if (nextValue) {
      const { width, height } = await getImageDimensions(nextValue);

      analyticsPayload = getAddAttemptAnalyticsPayload({
        width,
        height,
        mimeType: nextValue.type,
        source: 'upload',
        size: nextValue.size,
      });

      addPageAction(`IdV: ${name} image added`, analyticsPayload);
    }

    onChangeAndResetError(nextValue, analyticsPayload);
  }

  type LoggedClickCallback = (...args: any[]) => any;

  /**
   * Given a click source, returns a higher-order function that, when called, will log an event
   * before calling the original function.
   */
  function withLoggedClick(source: string, metadata: { isDrop: boolean } = { isDrop: false }) {
    return (fn: LoggedClickCallback) =>
      (...args: Parameters<LoggedClickCallback>) => {
        if (!isSuppressingClickLogging.current) {
          addPageAction(`IdV: ${name} image clicked`, { source, ...metadata });
        }

        return fn(...args);
      };
  }

  /**
   * Calls the given function, during which time any normal click logging will be suppressed.
   *
   */
  function withoutClickLogging(fn: () => any) {
    isSuppressingClickLogging.current = true;
    fn();
    isSuppressingClickLogging.current = false;
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
   * Responds to a click by starting capture if supported in the environment, or triggering the
   * default file picker prompt. The click event may originate from the file input itself, or
   * another element which aims to trigger the prompt of the file input.
   */
  function startCaptureOrTriggerUpload(event: MouseEvent) {
    if (event.target === inputRef.current) {
      if (forceNativeCamera) {
        addPageAction('IdV: Native camera forced after failed attempts', {
          field: name,
          failed_attempts: failedCaptureAttempts,
        });
        return forceUpload();
      }
      const isAcuantCaptureCapable = hasCapture && !acuantFailureCookie;
      const shouldStartAcuantCapture =
        isAcuantCaptureCapable && capture !== 'user' && !isForceUploading.current;
      const shouldStartSelfieCapture =
        isAcuantLoaded && capture === 'user' && !isForceUploading.current;

      if (!allowUpload || shouldStartSelfieCapture || shouldStartAcuantCapture) {
        event.preventDefault();
      }

      if (shouldStartSelfieCapture) {
        window.AcuantPassiveLiveness.startSelfieCapture(
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

  function onAcuantImageCaptureSuccess(nextCapture: AcuantSuccessResponse) {
    const { image, cardType, dpi, moire, glare, sharpness } = nextCapture;
    const isAssessedAsGlare = glare < glareThreshold;
    const isAssessedAsBlurry = sharpness < sharpnessThreshold;
    const { width, height, data } = image;

    let assessment: AcuantImageAssessment;
    if (isAssessedAsGlare) {
      setOwnErrorMessage(t('doc_auth.errors.glare.failed_short'));
      assessment = 'glare';
    } else if (isAssessedAsBlurry) {
      setOwnErrorMessage(t('doc_auth.errors.sharpness.failed_short'));
      assessment = 'blurry';
    } else {
      assessment = 'success';
    }

    const analyticsPayload: AcuantImageAnalyticsPayload = getAddAttemptAnalyticsPayload({
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

    addPageAction(`IdV: ${name} image added`, analyticsPayload);

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
            const { SEQUENCE_BREAK_CODE } = window.AcuantJavascriptWebSdk;
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
            addPageAction('IdV: Image capture failed', {
              field: name,
              error: getNormalizedAcuantCaptureFailureMessage(error, code),
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
