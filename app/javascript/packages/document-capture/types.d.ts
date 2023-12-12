import { AcuantCaptureFailureError, AcuantSuccessResponse } from './components/acuant-camera';
import { n } from 'msw/lib/glossary-de6278a9';

/**
 * Some of the other modules still refer to
 * AcuantGlobal, which should be equivalent to the
 * Window
 */
type AcuantGlobal = Window;

/**
 * @see https://github.com/Acuant/JavascriptWebSDKV11/blob/11.4.3/SimpleHTMLApp/webSdk/dist/AcuantJavascriptWebSdk.js#L1025-L1027
 * @see https://github.com/Acuant/JavascriptWebSDKV11/blob/11.4.3/SimpleHTMLApp/webSdk/dist/AcuantJavascriptWebSdk.js#L1049
 */
interface AcuantConfig {
  path: string;
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

type AcuantCaptureType = 'AUTO' | 'TAP';

type AcuantCameraStart = (
  callback: (response: AcuantImage) => void,
  errorCallback: Function,
) => void;

type AcuantCameraTriggerCapture = (callback: (response: AcuantImage) => void) => void;

declare enum AcuantDocumentStateEnum {
  NO_DOCUMENT = 0,
  SMALL_DOCUMENT = 1,
  BIG_DOCUMENT = 2,
  GOOD_DOCUMENT = 3,
}

declare enum AcuantUIStateEnum {
  CAPTURING = -1,
  TAP_TO_CAPTURE = -2,
}

type AcuantFrameState = AcuantDocumentStateEnum & AcuantUIStateEnum;

interface AcuantDetectedResult {
  state: AcuantFrameState;
}

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

type AcuantCameraCrop = (
  data: string,
  width: number,
  height: number,
  capType: AcuantCaptureType,
  callback: (result: AcuantImage) => void,
) => void;

type AcuantCameraEvaluateImage = (
  image: ImageData,
  width: number,
  height: number,
  captureType: string,
  callback: (result: AcuantEvaluatedResult) => void,
) => void;
interface AcuantCameraInterface {
  start: AcuantCameraStart;
  startManualCapture: (callback: AcuantCameraUICallbacks) => void;
  triggerCapture: AcuantCameraTriggerCapture;
  crop: AcuantCameraCrop;
  isCameraSupported: boolean;
  evaluateImage: AcuantCameraEvaluateImage;
}

interface AcuantEvaluatedResult {
  cardType: number;
  dpi: number;
  glare: number;
  sharpness: number;
  moire: number;
  image: {
    width: number;
    height: number;
    bytes: Uint8ClampedArray;
  };
  signedImage: string;
  isPortraitOrientation: boolean;
}
