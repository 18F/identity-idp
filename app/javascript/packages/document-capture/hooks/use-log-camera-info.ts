import { useEffect, useContext, useRef } from 'react';
import AnalyticsContext from '../context/analytics';

function getConstraints(deviceId) {
  return {
    video: {
      width: {
        ideal: 999999,
      },
      height: {
        ideal: 999999,
      },
      deviceId: {
        exact: deviceId,
      },
    },
  };
}

function getCameraInfo(videoTrack) {
  const cameraInfo = {
    label: videoTrack.label,
    frameRate: videoTrack.getSettings().frameRate,
    height: videoTrack.getSettings().height,
    width: videoTrack.getSettings().width,
  };
  return cameraInfo;
}

async function updateConstraintsAndLogInfo(videoDevice, trackEvent) {
  // See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints/facingMode
  const updatedConstraints = getConstraints(videoDevice.deviceId);
  try {
    const stream = await navigator.mediaDevices.getUserMedia(updatedConstraints);
    const videoTracks = stream.getVideoTracks();
    const cameras = videoTracks.map((videoTrack) => getCameraInfo(videoTrack));
    const logInfo = {
      camera_info: cameras,
    };
    trackEvent('IdV: camera info logged', logInfo);
  } catch (error) {
    trackEvent('IdV: camera info error', error);
  }
}

async function logCameraInfo(trackEvent) {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const videoDevices = devices.filter((device) => device.kind === 'videoinput');
  videoDevices.forEach((videoDevice) => {
    updateConstraintsAndLogInfo(videoDevice, trackEvent);
  });
}

function useLogCameraInfo({ isBackOfId, hasStartedCropping }) {
  const didLogCameraInfoRef = useRef(false);
  const { trackEvent } = useContext(AnalyticsContext);

  useEffect(() => {
    if (!isBackOfId) {
      return;
    }
    if (hasStartedCropping && !didLogCameraInfoRef.current) {
      logCameraInfo(trackEvent);
      didLogCameraInfoRef.current = true;
    }
  }, [didLogCameraInfoRef, hasStartedCropping, isBackOfId, trackEvent]);
}

export { useLogCameraInfo };
