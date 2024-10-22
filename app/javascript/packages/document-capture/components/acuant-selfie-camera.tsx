import { useContext, useEffect } from 'react';
import type { ReactNode } from 'react';
import { t } from '@18f/identity-i18n';
import AcuantContext from '../context/acuant';

declare global {
  interface Window {
    AcuantPassiveLiveness: AcuantPassiveLivenessInterface;
  }
}

type AcuantPassiveLivenessStart = (
  faceCaptureCallback: FaceCaptureCallback,
  faceDetectionStates: FaceDetectionStates,
) => void;

interface AcuantPassiveLivenessInterface {
  /**
   * Start capture
   */
  start: AcuantPassiveLivenessStart;
  /**
   * End capture
   */
  end: () => void;
}

interface AcuantSelfieCameraContextProps {
  /**
   * Success callback
   */
  onImageCaptureSuccess: ({ image }: { image: string }) => void;
  /**
   * Failure callback
   */
  onImageCaptureFailure: (error: { code: number; message: string }) => void;
  /**
   * Capture open callback, tells the rest of the page
   * when the fullscreen selfie capture page is open
   */
  onImageCaptureOpen: () => void;
  /**
   * Capture close callback, tells the rest of the page
   * when the fullscreen selfie capture page has been closed
   */
  onImageCaptureClose: () => void;
  /**
   * Capture hint text from onDetection callback, tells the user
   * why the acuant sdk cannot capture a selfie.
   */
  onImageCaptureFeedback: (text: string) => void;
  /**
   * Selfie taken, ready for accept or retake
   */
  onSelfieTaken: () => void;
  /**
   * Selfie captured by user initiated retake
   */
  onSelfieRetaken: () => void;
  /**
   * React children node
   */
  children: ReactNode;
  /**
   * Face detection is initialized and ready.
   */
  onImageCaptureInitialized: () => void;
}

interface FaceCaptureCallback {
  onDetectorInitialized: () => void;
  onDetection: (text) => void;
  onOpened: () => void;
  onClosed: () => void;
  onError: (error) => void;
  onPhotoTaken: () => void;
  onPhotoRetake: () => void;
  onCaptured: (base64Image: Blob) => void;
}

interface FaceDetectionStates {
  FACE_NOT_FOUND: string;
  TOO_MANY_FACES: string;
  FACE_TOO_SMALL: string;
  FACE_CLOSE_TO_BORDER: string;
  CLOSE_TEXT: string;
  RETAKE_TEXT: string;
  INTRO_TEXT: string;
  SUBMIT_ALT: string;
  CAPTURE_ALT: string;
}

function AcuantSelfieCamera({
  onImageCaptureInitialized = () => {},
  onImageCaptureSuccess = () => {},
  onImageCaptureFailure = () => {},
  onImageCaptureOpen = () => {},
  onImageCaptureClose = () => {},
  onImageCaptureFeedback = () => {},
  onSelfieTaken = () => {},
  onSelfieRetaken = () => {},
  children,
}: AcuantSelfieCameraContextProps) {
  const { isReady, setIsActive } = useContext(AcuantContext);

  useEffect(() => {
    const faceCaptureCallback: FaceCaptureCallback = {
      onDetectorInitialized: () => {
        // This callback is triggered when the face detector is ready.
        // Until then, no actions are executed and the user sees only the camera stream.
        // You can opt to display an alert before the callback is triggered.
        onImageCaptureInitialized();
      },
      onDetection: (text) => {
        onImageCaptureFeedback(text);
        // Triggered when the face does not pass the scan. The UI element
        // should be updated here to provide guidence to the user
      },
      onOpened: () => {
        // Camera has opened
        onImageCaptureFeedback('');
        onImageCaptureOpen();
      },
      onClosed: () => {
        // Camera has closed
        onImageCaptureFeedback('');
        onImageCaptureClose();
      },
      onError: (error) => {
        // Error occurred. Camera permission not granted will
        // manifest here with 1 as error code. Unexpected errors will have 2 as error code.
        onImageCaptureFailure(error);
      },
      onPhotoTaken: () => {
        // The photo has been taken and it's showing a preview with a button to accept or retake the image.
        onSelfieTaken();
      },
      onPhotoRetake: () => {
        // Triggered when retake button is tapped
        onSelfieRetaken();
      },
      onCaptured: (base64Image) => {
        // Triggered when accept button is tapped
        onImageCaptureSuccess({ image: `data:image/jpeg;base64,${base64Image}` });
      },
    };

    const faceDetectionStates = {
      FACE_NOT_FOUND: t('doc_auth.info.selfie_capture_status.face_not_found'),
      TOO_MANY_FACES: t('doc_auth.info.selfie_capture_status.too_many_faces'),
      FACE_TOO_SMALL: t('doc_auth.info.selfie_capture_status.face_too_small'),
      FACE_CLOSE_TO_BORDER: t('doc_auth.info.selfie_capture_status.face_close_to_border'),
      CLOSE_TEXT: t('doc_auth.info.selfie_capture.action.close'),
      RETAKE_TEXT: t('doc_auth.info.selfie_capture.action.retake'),
      INTRO_TEXT: t('doc_auth.info.selfie_capture.intro'),
      SUBMIT_ALT: t('doc_auth.info.selfie_capture.action.submit'),
      CAPTURE_ALT: t('doc_auth.info.selfie_capture.action.capture'),
    };
    const cleanupSelfieCamera = () => {
      window.AcuantPassiveLiveness?.end();
      setIsActive(false);
    };

    const startSelfieCamera = () => {
      window.AcuantPassiveLiveness?.start(faceCaptureCallback, faceDetectionStates);
      setIsActive(true);
    };

    if (isReady) {
      startSelfieCamera();
    }
    // Cleanup when the AcuantSelfieCamera component is unmounted
    return () => (isReady ? cleanupSelfieCamera() : undefined);
  }, [isReady]);

  return <>{children}</>;
}

export default AcuantSelfieCamera;
