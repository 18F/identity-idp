import { useContext, useEffect } from 'react';
import type { ReactNode } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { useImmutableCallback } from '@18f/identity-react-hooks';
import AcuantContext from '../context/acuant';

declare global {
  interface Window {
    AcuantCameraUI: AcuantCameraUIInterface;
  }
}

/**
 * Type definition for export only
 */
type AcuantGlobals = {
  AcuantCameraUI: AcuantCameraUIInterface;
  AcuantCamera: AcuantCameraInterface;
};
export type AcuantGlobal = Window & AcuantGlobals;

enum AcuantDocumentStateEnum {
  NO_DOCUMENT = 0,
  SMALL_DOCUMENT = 1,
  BIG_DOCUMENT = 2,
  GOOD_DOCUMENT = 3,
}

/**
 * @enum {number}
 */
export const AcuantDocumentState = {
  NO_DOCUMENT: 0,
  SMALL_DOCUMENT: 1,
  BIG_DOCUMENT: 2,
  GOOD_DOCUMENT: 3,
};

enum AcuantUIStateEnum {
  CAPTURING = -1,
  TAP_TO_CAPTURE = -2,
}

/**
 * @enum {number}
 */
export const AcuantUIState = {
  CAPTURING: -1,
  TAP_TO_CAPTURE: -2,
};

type AcuantFrameState = AcuantDocumentStateEnum & AcuantUIStateEnum;

type AcuantCaptureType = 'AUTO' | 'TAP';

interface AcuantCameraUIText {
  /**
   * No document detected.
   */
  NONE: string;

  /**
   * Document does not fill frame.
   */
  SMALL_DOCUMENT: string;

  /**
   * Document is too close to the frame.
   */
  BIG_DOCUMENT: string;

  /**
   * Document is good and capture is pending.
   */
  GOOD_DOCUMENT: string | null;

  /**
   * Document is being captured.
   */
  CAPTURING: string;

  /**
   * Explicit user action to capture after delay.
   */
  TAP_TO_CAPTURE: string;
}

/**
 * @prop text Camera UI text strings.
 */
interface AcuantCameraUIOptions {
  text: AcuantCameraUIText;
}

/**
 * We call String.toLowerCase() on these when sending analytics events to the server
 */
export enum AcuantDocumentType {
  NONE = 0,
  ID = 1,
  PASSPORT = 2,
}

export type AcuantCaptureFailureError =
  | undefined // Cropping failure (SDK v11.5.0, L1171)
  | 'Camera not supported.' // Camera not supported (SDK v11.5.0, L978)
  | 'already started.' // Capture already started (SDK v11.5.0, L724)
  | 'Missing HTML elements.' // Required page elements are not available (SDK v11.5.0, L727)
  | Error // User or system denied camera access (SDK v11.5.0, L673)
  | "Expected div with 'acuant-camera' id" // Failure to setup due to missing element (SDK v11.5.0, L706)
  | 'Live capture has previously failed and was called again. User was sent to manual capture.' // Previous failure (SDK v11.5.0, L698)
  | 'sequence-break'; // iOS 15 sequence break (SDK v11.5.0, L1327)

interface AcuantCameraUICallbacks {
  /**
   * Document captured callback.
   */
  onCaptured: (response: AcuantCaptureImage) => void;
  /**
   * Document cropped callback. Null if
   * cropping error.
   */
  onCropped: (response: AcuantSuccessResponse | null) => void;
  /**
   * Optional frame available callback
   */
  onFrameAvailable?: (response: AcuantDetectedResult) => void;
  /**
   * Callback that occurs when there is a failure.
   */
  onError: (error?: AcuantCaptureFailureError, code?: string) => void;
}

type AcuantCameraUIStart = (
  callbacks: AcuantCameraUICallbacks,
  onFailureCallbackWithOptions: AcuantFailureCallback,
  options?: AcuantCameraUIOptions,
) => void;

interface AcuantCameraUIInterface {
  /**
   * Start capture
   */
  start: AcuantCameraUIStart;
  /**
   * End capture
   */
  end: () => void;
}

type AcuantCameraStart = (callback: (response: AcuantImage) => void, errorCallback: Function) => void;
type AcuantCameraTriggerCapture = (callback: (response: AcuantImage) => void) => void;
type AcuantCameraCrop = (
  data: string,
  width: number,
  height: number,
  capType: AcuantCaptureType,
  callback: (result: AcuantImage) => void,
) => void;

declare global {
  interface AcuantCameraInterface {
    start: AcuantCameraStart;
    startManualCapture: (callback: AcuantCameraUICallbacks) => void;
    triggerCapture: AcuantCameraTriggerCapture;
    crop: AcuantCameraCrop;
  }
}

interface AcuantCaptureImage {
  /**
   * Pre-cropped image data
   */
  data: Blob;
  /**
   * Image width
   */
  width: number;
  /**
   * Image height
   */
  height: number;
}

interface AcuantImage {
  /**
   * Base64-encoded image data
   */
  data: string;
  /**
   * Image width
   */
  width: number;
  /**
   * Image height
   */
  height: number;
}

interface AcuantDetectedResult {
  state: AcuantFrameState;
}

/**
 * @see https://github.com/Acuant/JavascriptWebSDKV11/?tab=readme-ov-file#image-from-acuantcameraui-and-acuantcamera
 */
export interface AcuantSuccessResponse {
  /**
   * Image object
   */
  image: AcuantImage;
  /**
   * Document type for Acuant SDK
   */
  cardType: AcuantDocumentType;
  /**
   * Detected image glare
   */
  glare: number;
  /**
   * Detected image sharpness
   */
  sharpness: number;
  /**
   * Detected image moire
   */
  moire: number;
  /**
   * Detected image raw moire
   */
  moireraw: number;
  /**
   * Detected image resolution
   */
  dpi: number;
}

type AcuantSuccessCallback = (response: AcuantSuccessResponse) => void;

type AcuantFailureCallback = (error?: AcuantCaptureFailureError, code?: string) => void;

interface AcuantCameraContextProps {
  /**
   * Success callback
   */
  onImageCaptureSuccess: AcuantSuccessCallback;
  /**
   * Failure callback
   */
  onImageCaptureFailure: AcuantFailureCallback;
  /**
   * Crop started callback, invoked after capture is made and before image has been evaluated
   */
  onCropStart: () => void;
  /**
   * React children node
   */
  children: ReactNode;
}

function AcuantCamera({
  onImageCaptureSuccess = () => {},
  onImageCaptureFailure = () => {},
  onCropStart = () => {},
  children,
}: AcuantCameraContextProps) {
  const { isReady, setIsActive } = useContext(AcuantContext);
  const { t } = useI18n();
  const onCropped = useImmutableCallback(
    (response) => {
      if (response) {
        onImageCaptureSuccess(response);
      } else {
        onImageCaptureFailure();
      }
    },
    [onImageCaptureSuccess],
  );

  useEffect(() => {
    const textOptions = {
      text: {
        NONE: t('doc_auth.info.capture_status_none'),
        SMALL_DOCUMENT: t('doc_auth.info.capture_status_small_document'),
        BIG_DOCUMENT: t('doc_auth.info.capture_status_big_document'),
        GOOD_DOCUMENT: null,
        CAPTURING: t('doc_auth.info.capture_status_capturing'),
        TAP_TO_CAPTURE: t('doc_auth.info.capture_status_tap_to_capture'),
      },
    };
    if (isReady) {
      const onFailureCallbackWithOptions = (...args) => onImageCaptureFailure(...args);
      Object.keys(textOptions).forEach((key) => {
        onFailureCallbackWithOptions[key] = textOptions[key];
      });

      window.AcuantCameraUI.start(
        {
          onCaptured: onCropStart,
          onCropped,
          onError: onImageCaptureFailure,
        },
        onFailureCallbackWithOptions,
        textOptions,
      );
      setIsActive(true);
    }

    return () => {
      if (isReady) {
        window.AcuantCameraUI.end();
        setIsActive(false);
      }
    };
  }, [isReady]);

  return <>{children}</>;
}

export default AcuantCamera;
