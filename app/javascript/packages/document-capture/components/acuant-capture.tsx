import { Button, FullScreen } from '@18f/identity-components';
import type { MouseEvent, ReactNode, Ref } from 'react';
import {
  forwardRef,
  useContext,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
} from 'react';
import type { FocusTrap } from 'focus-trap';
import type { FullScreenRefHandle } from '@18f/identity-components';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import { useI18n } from '@18f/identity-react-i18n';
import { removeUnloadProtection } from '@18f/identity-url';
import AcuantCamera, { AcuantDocumentType } from './acuant-camera';
import AcuantSelfieCamera from './acuant-selfie-camera';
import AcuantSelfieCaptureCanvas from './acuant-selfie-capture-canvas';
import type {
  AcuantCaptureFailureError,
  AcuantSuccessResponse,
  LegacyAcuantSuccessResponse,
} from './acuant-camera';
import AcuantCaptureCanvas from './acuant-capture-canvas';
import AcuantContext, { AcuantCaptureMode } from '../context/acuant';
import AnalyticsContext from '../context/analytics';
import DeviceContext from '../context/device';
import FailedCaptureAttemptsContext from '../context/failed-capture-attempts';
import FileInput from './file-input';
import UploadContext from '../context/upload';
import useCookie from '../hooks/use-cookie';
import useCounter from '../hooks/use-counter';
import type { AcuantEvaluatedResult } from '../types';

type AcuantImageAssessment = 'success' | 'glare' | 'blurry' | 'unsupported';
type ImageSource = 'acuant' | 'upload';

interface ImageAnalyticsPayload {
  /**
   * Image width, or null if unknown
   */
  width: number | null;
  /**
   * Image height, or null if unknown
   */
  height: number | null;
  /**
   * Mime type, or null if unknown
   */
  mimeType: string | null;
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
  /**
   * Whether the Acuant SDK captured the image automatically, or using the tap to
   * capture functionality
   */
  acuantCaptureMode?: AcuantCaptureMode | null;

  /**
   * Fingerprint of the image, base64 encoded SHA-256 digest
   */
  fingerprint: string | null;

  /**
   *
   */
  failedImageResubmission: boolean;
}

interface AcuantImageAnalyticsPayload extends ImageAnalyticsPayload {
  documentType: string;
  dpi: number;
  moire: number;
  glare: number;
  glareScoreThreshold: number;
  isAssessedAsGlare: boolean;
  sharpness: number;
  sharpnessScoreThreshold: number;
  isAssessedAsBlurry: boolean;
  assessment: AcuantImageAssessment;
  isAssessedAsUnsupported: boolean;
}

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
export const isAcuantCameraAccessFailure = (error: AcuantCaptureFailureError): error is Error =>
  error instanceof Error;

/**
 * Returns a human-readable document label corresponding to the given document type constant,
 * such as "id" "passport" or "none"
 */
const getDocumentTypeLabel = (documentType: AcuantDocumentType): string =>
  AcuantDocumentType[documentType]?.toLowerCase() ??
  `An error in document type returned: ${documentType}`;

export function getNormalizedAcuantCaptureFailureMessage(
  error: AcuantCaptureFailureError,
  code: string | undefined,
): string {
  if (isAcuantCameraAccessFailure(error)) {
    return 'User or system denied camera access';
  }

  const { REPEAT_FAIL_CODE, SEQUENCE_BREAK_CODE } = window.AcuantJavascriptWebSdk;

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

function dataURItoFile(fileName: string, dataURI: string): File {
  const byteString = atob(dataURI.split(',')[1]);
  const mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0];
  const unit8Array = new Uint8Array(Array.from(byteString, (char) => char.charCodeAt(0)));
  return new File([unit8Array], fileName, { type: mimeString });
}

function getFingerPrint(file: File): Promise<string | null> {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = () => {
      const dataBuffer = reader.result;
      window.crypto.subtle
        .digest('SHA-256', dataBuffer as ArrayBuffer)
        .then((arrayBuffer) => {
          const digestArray = new Uint8Array(arrayBuffer);
          const strDigest = digestArray.reduce(
            (data, byte) => data + String.fromCharCode(byte),
            '',
          );
          const base64String = window.btoa(strDigest);
          const urlSafeBase64String = base64String
            .replace(/\+/g, '-')
            .replace(/\//g, '_')
            .replace(/=+$/, '');
          resolve(urlSafeBase64String);
        })
        .catch(() => null);
    };
    reader.readAsArrayBuffer(file);
  });
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

function evaluateImage(
  width: number,
  height: number,
  file: File,
): Promise<AcuantEvaluatedResult | null> {
  let croppedImg: AcuantEvaluatedResult;
  if (window.AcuantCamera === undefined) {
    return Promise.resolve(null);
  }
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = (event: ProgressEvent<FileReader>) => {
      const img = new Image();
      img.onload = function () {
        const canvas = document.createElement('canvas');
        canvas.width = img.width;
        canvas.height = img.height;
        const ctx = canvas.getContext('2d');
        ctx?.drawImage(img, 0, 0);
        const imageData = ctx?.getImageData(0, 0, canvas.width, canvas.height);
        window.AcuantCamera.evaluateImage(
          imageData as ImageData,
          width,
          height,
          false,
          'MANUAL',
          (result: AcuantEvaluatedResult) => {
            croppedImg = result;
            resolve(croppedImg);
          },
        );
      };
      img.onerror = function () {
        resolve(null);
      };
      img.src = event?.target?.result as string;
    };
    reader.readAsDataURL(file);
  });
}

function processImage(file: File): Promise<{
  width: number | null;
  height: number | null;
  croppedImg: File;
}> {
  let croppedImg: AcuantEvaluatedResult;
  if (window.AcuantCamera === undefined) {
    return Promise.resolve({ width: null, height: null, croppedImg: file });
  }
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = (event: ProgressEvent<FileReader>) => {
      const img = new Image();
      img.onload = function () {
        const canvas = document.createElement('canvas');
        const { width, height } = img;
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');
        ctx?.drawImage(img, 0, 0);
        const imageData = ctx?.getImageData(0, 0, canvas.width, canvas.height);
        window.AcuantCamera.evaluateImage(
          imageData as ImageData,
          width,
          height,
          false,
          'MANUAL',
          (result: AcuantEvaluatedResult) => {
            croppedImg = result;
            let newFile = file;
            if (croppedImg?.image?.data) {
              const newImgFile = dataURItoFile(file.name, croppedImg.image.data);
              if (newImgFile?.size) {
                newFile = newImgFile;
              }
            }
            resolve({ width, height, croppedImg: newFile });
          },
        );
      };
      img.onerror = function () {
        resolve({ width: null, height: null, croppedImg: file });
      };
      img.src = event?.target?.result as string;
    };
    reader.readAsDataURL(file);
  });
}

function getImageMetadata(
  file: File,
): Promise<{ width: number | null; height: number | null; fingerprint: string | null }> {
  const dimension = getImageDimensions(file);
  const fingerprint = getFingerPrint(file);
  return new Promise<{ width: number | null; height: number | null; fingerprint: string | null }>(
    function (resolve) {
      Promise.all([dimension, fingerprint])
        .then((results) => {
          resolve({ width: results[0].width, height: results[0].height, fingerprint: results[1] });
        })
        .catch(() => ({ width: null, height: null, fingerprint: null }));
    },
  );
}

function getImageMetadataEnhanced(file: File): Promise<{
  width: number | null;
  height: number | null;
  croppedImg: File;
  fingerprint: string | null;
}> {
  const processedData = processImage(file);
  const fingerprint = getFingerPrint(file);
  return new Promise<{
    width: number | null;
    height: number | null;
    croppedImg: File;
    fingerprint: string | null;
  }>(function (resolve) {
    Promise.all([processedData, fingerprint])
      .then((results) => {
        resolve({
          width: results[0].width,
          height: results[0].height,
          croppedImg: results[0].croppedImg,
          fingerprint: results[1],
        });
      })
      .catch(() => ({ width: null, height: null, croppedImg: file, fingerprint: null }));
  });
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

export function getDecodedBase64ByteSize(data: string) {
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
    acuantCaptureMode,
    isError,
    isCameraSupported,
    glareThreshold,
    sharpnessThreshold,
  } = useContext(AcuantContext);
  const { isMockClient } = useContext(UploadContext);
  const { trackEvent } = useContext(AnalyticsContext);
  const fullScreenRef = useRef<FullScreenRefHandle>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const isForceUploading = useRef(false);
  const isSuppressingClickLogging = useRef(false);
  const [isCapturingEnvironment, setIsCapturingEnvironment] = useState(false);
  const [ownErrorMessage, setOwnErrorMessage] = useState<string | null>(null);
  const [hasStartedCropping, setHasStartedCropping] = useState(false);
  useMemo(() => setOwnErrorMessage(null), [value]);
  const { isMobile } = useContext(DeviceContext);
  const { t, formatHTML } = useI18n();
  const [attempt, incrementAttempt] = useCounter(1);
  const [acuantFailureCookie, setAcuantFailureCookie, refreshAcuantFailureCookie] =
    useCookie('AcuantCameraHasFailed');
  // There's some pretty significant changes to this component when it's used for
  // selfie capture vs document image capture. This controls those changes.
  const selfieCapture = name === 'selfie';

  const {
    failedCaptureAttempts,
    onFailedCaptureAttempt,
    failedCameraPermissionAttempts,
    onFailedCameraPermissionAttempt,
    onResetFailedCaptureAttempts,
    failedSubmissionAttempts,
    forceNativeCamera,
    failedSubmissionImageFingerprints,
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
    metadata?: ImageAnalyticsPayload,
  ) {
    setOwnErrorMessage(null);
    onChange(nextValue, metadata);
  }

  /**
   * Returns an analytics payload, decorated with common values.
   */
  function getAddAttemptAnalyticsPayload<
    P extends ImageAnalyticsPayload | AcuantImageAnalyticsPayload,
  >(payload: P): P {
    const enhancedPayload = {
      ...payload,
      attempt,
      acuantCaptureMode: payload.source === 'upload' ? null : acuantCaptureMode,
    };
    incrementAttempt();
    return enhancedPayload;
  }

  /**
   * Handler for file input change events.
   */
  async function onUpload(nextValue: File | null) {
    let analyticsPayload: ImageAnalyticsPayload | undefined;
    let hasFailed = false;

    if (nextValue) {
      const { width, height, fingerprint } = await getImageMetadata(nextValue);
      hasFailed = failedSubmissionImageFingerprints[name]?.includes(fingerprint);
      analyticsPayload = getAddAttemptAnalyticsPayload({
        width,
        height,
        fingerprint,
        mimeType: nextValue.type,
        source: 'upload',
        size: nextValue.size,
        failedImageResubmission: hasFailed,
      });
      trackEvent(`IdV: ${name} image added`, analyticsPayload);
      const newImg = await evaluateImage(width as number, height as number, nextValue);
      if (newImg?.image?.data) {
        const newImgFile = dataURItoFile(nextValue.name, newImg.image.data);
        if (newImgFile?.size) {
          nextValue = newImgFile;
        }
      }
    }

    onChangeAndResetError(nextValue, analyticsPayload);
  }

  async function onUploadEnhanced(nextValue: File | null) {
    let analyticsPayload: ImageAnalyticsPayload | undefined;
    let hasFailed = false;

    if (nextValue) {
      const { width, height, croppedImg, fingerprint } = await getImageMetadataEnhanced(nextValue);
      hasFailed = failedSubmissionImageFingerprints[name]?.includes(fingerprint);
      let source: ImageSource = 'upload';
      // file changed
      if (croppedImg && croppedImg.size !== nextValue.size) {
        nextValue = croppedImg;
        // it is cropped
        source = 'acuant';
      }
      analyticsPayload = getAddAttemptAnalyticsPayload({
        width,
        height,
        fingerprint,
        mimeType: nextValue.type,
        source,
        size: nextValue.size,
        failedImageResubmission: hasFailed,
      });
      trackEvent(`IdV: ${name} image added`, analyticsPayload);
    }
    onChangeAndResetError(nextValue, analyticsPayload);
  }

  /**
   * Given a click source, returns a higher-order function that, when called, will log an event
   * before calling the original function.
   */
  function withLoggedClick(source: string, metadata: { isDrop: boolean } = { isDrop: false }) {
    return <T extends (...args: any[]) => any>(fn: T) =>
      (...args: Parameters<T>) => {
        if (!isSuppressingClickLogging.current) {
          trackEvent(`IdV: ${name} image clicked`, { source, ...metadata });
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
      const isAcuantCaptureCapable = hasCapture && !acuantFailureCookie;
      const shouldStartAcuantCapture =
        isAcuantCaptureCapable && !isForceUploading.current && !forceNativeCamera;

      if (isAcuantCaptureCapable && forceNativeCamera) {
        trackEvent('IdV: Native camera forced after failed attempts', {
          field: name,
          failed_capture_attempts: failedCaptureAttempts,
          failed_submission_attempts: failedSubmissionAttempts,
        });
      }

      if (!allowUpload || shouldStartAcuantCapture) {
        event.preventDefault();
      }

      if (shouldStartAcuantCapture && !isAcuantInstanceActive) {
        setIsCapturingEnvironment(true);
      }

      isForceUploading.current = false;
    } else {
      withoutClickLogging(() => inputRef.current?.click());
    }
  }

  function onSelfieCaptureSuccess({ image }: { image: string }) {
    onChangeAndResetError(image);
    onResetFailedCaptureAttempts();
    setIsCapturingEnvironment(false);
  }

  function onSelfieCaptureFailure() {
    // Internally, Acuant sets a cookie to bail on guided capture if initialization had
    // previously failed for any reason, including declined permission. Since the cookie
    // never expires, and since we want to re-prompt even if the user had previously
    // declined, unset the cookie value when failure occurs for permissions.
    setAcuantFailureCookie(null);
    onCameraAccessDeclined();

    // Due to a bug with Safari on iOS we force the page to refresh on the third
    // time a user denies permissions.
    onFailedCameraPermissionAttempt();
    if (failedCameraPermissionAttempts > 2) {
      removeUnloadProtection();
      window.location.reload();
    }
    setIsCapturingEnvironment(false);
  }

  function onAcuantImageCaptureSuccess(
    nextCapture: AcuantSuccessResponse | LegacyAcuantSuccessResponse,
  ) {
    const { image, dpi, moire, glare, sharpness } = nextCapture;
    const cardType = 'cardType' in nextCapture ? nextCapture.cardType : nextCapture.cardtype;

    const isAssessedAsGlare = glare < glareThreshold;
    const isAssessedAsBlurry = sharpness < sharpnessThreshold;
    const isAssessedAsUnsupported = cardType !== AcuantDocumentType.ID;
    const { width, height, data } = image;

    let assessment: AcuantImageAssessment;
    if (isAssessedAsBlurry) {
      setOwnErrorMessage(t('doc_auth.errors.sharpness.failed_short'));
      assessment = 'blurry';
    } else if (isAssessedAsGlare) {
      setOwnErrorMessage(t('doc_auth.errors.glare.failed_short'));
      assessment = 'glare';
    } else if (isAssessedAsUnsupported) {
      setOwnErrorMessage(t('doc_auth.errors.card_type'));
      assessment = 'unsupported';
    } else {
      assessment = 'success';
    }

    const analyticsPayload: AcuantImageAnalyticsPayload = getAddAttemptAnalyticsPayload({
      width,
      height,
      mimeType: 'image/jpeg', // Acuant Web SDK currently encodes all images as JPEG
      source: 'acuant',
      isAssessedAsUnsupported,
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
      fingerprint: null,
      failedImageResubmission: false,
    });

    trackEvent(`IdV: ${name} image added`, analyticsPayload);

    if (assessment === 'success') {
      onChangeAndResetError(data, analyticsPayload);
      onResetFailedCaptureAttempts();
    } else {
      onFailedCaptureAttempt({
        isAssessedAsGlare,
        isAssessedAsBlurry,
        isAssessedAsUnsupported,
      });
    }

    setIsCapturingEnvironment(false);
  }

  function onAcuantImageCaptureFailure(error: AcuantCaptureFailureError, code: string | undefined) {
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

      // Due to a bug with Safari on iOS we force the page to refresh on the third
      // time a user denies permissions.
      onFailedCameraPermissionAttempt();
      if (failedCameraPermissionAttempts > 2) {
        removeUnloadProtection();
        window.location.reload();
      }
    } else if (code === SEQUENCE_BREAK_CODE) {
      setOwnErrorMessage(
        `${t('doc_auth.errors.upload_error')} ${t('errors.messages.try_again')
          .split(' ')
          .join(NBSP_UNICODE)}`,
      );

      refreshAcuantFailureCookie();
    } else if (error === undefined) {
      // Show a more generic error message when there's a cropping error.
      // Errors with a value of `undefined` are cropping errors.
      setOwnErrorMessage(t('errors.general'));
    } else {
      setOwnErrorMessage(t('doc_auth.errors.camera.failed'));
    }

    setIsCapturingEnvironment(false);
    trackEvent('IdV: Image capture failed', {
      field: name,
      acuantCaptureMode,
      error: getNormalizedAcuantCaptureFailureMessage(error, code),
    });
  }

  return (
    <div className={[className, 'document-capture-acuant-capture'].filter(Boolean).join(' ')}>
      {isCapturingEnvironment && !selfieCapture && (
        <AcuantCamera
          onCropStart={() => setHasStartedCropping(true)}
          onImageCaptureSuccess={onAcuantImageCaptureSuccess}
          onImageCaptureFailure={onAcuantImageCaptureFailure}
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
      {isCapturingEnvironment && selfieCapture && (
        <AcuantSelfieCamera
          onImageCaptureSuccess={onSelfieCaptureSuccess}
          onImageCaptureFailure={onSelfieCaptureFailure}
          onImageCaptureOpen={() => setIsCapturingEnvironment(true)}
          onImageCaptureClose={() => setIsCapturingEnvironment(false)}
        >
          <AcuantSelfieCaptureCanvas
            fullScreenRef={fullScreenRef}
            fullScreenLabel={t('doc_auth.accessible_labels.document_capture_dialog')}
            onRequestClose={() => setIsCapturingEnvironment(false)}
          />
        </AcuantSelfieCamera>
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
        value={value}
        errorMessage={ownErrorMessage ?? errorMessage}
        isValuePending={hasStartedCropping}
        onClick={withLoggedClick('placeholder')(startCaptureOrTriggerUpload)}
        onDrop={withLoggedClick('placeholder', { isDrop: true })(noop)}
        onChange={onUploadEnhanced}
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
          formatHTML(t('doc_auth.buttons.take_or_upload_picture_html'), {
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
export { AcuantDocumentType };
