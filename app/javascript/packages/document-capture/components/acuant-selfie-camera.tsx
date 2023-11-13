import React, { useContext, useEffect } from 'react';
import type { ReactNode } from 'react';
import AcuantContext from '../context/acuant';

declare global {
  interface Window {
    AcuantPassiveLiveness: any;
  }
}

type AcuantPassiveLivenessStart = () => void;

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

interface AcuantCameraContextProps {
  /**
   * Success callback
   */
  onImageCaptureSuccess: any;
  /**
   * React children node
   */
  children: ReactNode;
}

function AcuantCamera({ onImageCaptureSuccess = () => {}, children }: AcuantCameraContextProps) {
  const { isReady, setIsActive } = useContext(AcuantContext);
  const faceCaptureCallback = {
    onDetectorInitialized: () => {
      console.log('onDetectorInitialized');
      // This callback is triggered when the face detector is ready.
      // Until then, no actions are executed and the user sees only the camera stream.
      // You can opt to display an alert before the callback is triggered.
    },
    onDetection: (text) => {
      console.log('onDetection', text);
      // Triggered when the face does not pass the scan. The UI element
      // should be updated here to provide guidence to the user
    },
    onOpened: () => {
      // Camera has opened
      console.log('onOpened');
    },
    onClosed: () => {
      // Camera has closed
      console.log('onClosed');
    },
    onError: (error) => {
      // Error occurred. Camera permission not granted will
      // manifest here with 1 as error code. Unexpected errors will have 2 as error code.
      console.log('onError', error);
    },
    onPhotoTaken: () => {
      // The photo has been taken and it's showing a preview with a button to accept or retake the image.
      console.log('onPhotoTaken');
    },
    onPhotoRetake: () => {
      // Triggered when retake button is tapped
      console.log('onPhotoRetake');
    },
    onCaptured: (base64Image) => {
      // Triggered when accept button is tapped
      console.log('onCaptured', base64Image);
      onImageCaptureSuccess({
        image: { data: base64Image },
        cardType: 1, // TODO Drivers license, this is incorrect for selfie
        sharpness: 100, // TODO
        glare: 100, //TODO
      });
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
      console.log('cleanupSelfieCamera');
      window.AcuantPassiveLiveness.end();
      setIsActive(false);
    };
    const startSelfieCamera = () => {
      // TODO This opens the native camera
      //window.AcuantPassiveLiveness.startManualCapture((image) => console.log('image', image));
      window.AcuantPassiveLiveness.start(faceCaptureCallback, faceDetectionStates);
      setIsActive(true);
    };

    if (isReady) {
      startSelfieCamera();
    }
    return () => {
      if (isReady) {
        cleanupSelfieCamera();
      }
    };
  }, [isReady]);

  return <>{children}</>;
}

export default AcuantCamera;
