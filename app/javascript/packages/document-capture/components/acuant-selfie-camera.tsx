import React, { useContext, useEffect } from 'react';
import type { ReactNode } from 'react';
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
  onImageCaptureFailure: any;
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
   * React children node
   */
  children: ReactNode;
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
  FACE_ANGLE_TOO_LARGE: string;
  PROBABILITY_TOO_SMALL: string;
  FACE_TOO_SMALL: string;
  FACE_CLOSE_TO_BORDER: string;
}

function AcuantCamera({
  onImageCaptureSuccess = () => {},
  onImageCaptureFailure = () => {},
  onImageCaptureOpen = () => {},
  onImageCaptureClose = () => {},
  children,
}: AcuantSelfieCameraContextProps) {
  const { isReady, setIsActive } = useContext(AcuantContext);
  const faceCaptureCallback: FaceCaptureCallback = {
    onDetectorInitialized: () => {
      // This callback is triggered when the face detector is ready.
      // Until then, no actions are executed and the user sees only the camera stream.
      // You can opt to display an alert before the callback is triggered.
    },
    onDetection: () => {
      // Triggered when the face does not pass the scan. The UI element
      // should be updated here to provide guidence to the user
    },
    onOpened: () => {
      // Camera has opened
      onImageCaptureOpen();
    },
    onClosed: () => {
      // Camera has closed
      onImageCaptureClose();
    },
    onError: (error) => {
      // Error occurred. Camera permission not granted will
      // manifest here with 1 as error code. Unexpected errors will have 2 as error code.
      onImageCaptureFailure({ error });
    },
    onPhotoTaken: () => {
      // The photo has been taken and it's showing a preview with a button to accept or retake the image.
    },
    onPhotoRetake: () => {
      // Triggered when retake button is tapped
    },
    onCaptured: (base64Image) => {
      // Triggered when accept button is tapped
      onImageCaptureSuccess({ image: `data:image/jpeg;base64,${base64Image}` });
    },
  };

  useEffect(() => {
    const faceDetectionStates = {
      FACE_NOT_FOUND: 'FACE NOT FOUND',
      TOO_MANY_FACES: 'TOO MANY FACES',
      FACE_ANGLE_TOO_LARGE: 'FACE ANGLE TOO LARGE',
      PROBABILITY_TOO_SMALL: 'PROBABILITY TOO SMALL',
      FACE_TOO_SMALL: 'FACE TOO SMALL',
      FACE_CLOSE_TO_BORDER: 'TOO CLOSE TO THE FRAME',
    };
    const cleanupSelfieCamera = () => {
      window.AcuantPassiveLiveness.end();
      setIsActive(false);
    };

    const startSelfieCamera = () => {
      window.AcuantPassiveLiveness.start(faceCaptureCallback, faceDetectionStates);
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

export default AcuantCamera;
