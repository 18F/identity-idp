import { useState, useEffect, useContext } from 'react';
import AnalyticsContext from '../context/analytics';

function getConstraints(deviceId, facingMode) {
  return {
    video: {
      facingMode: { exact: facingMode },
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

async function updateConstraintsAndGetInfo(videoDevice, facingMode, trackEvent) {
  // See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints/facingMode
  const updatedConstraints = getConstraints(videoDevice.deviceId, facingMode);
  try {
    const stream = await navigator.mediaDevices.getUserMedia(updatedConstraints);
    const videoTracks = stream.getVideoTracks();
    const cameras = videoTracks.map((videoTrack) => getCameraInfo(videoTrack));
    const logInfo = {
      facing_mode: facingMode,
      camera_info: cameras,
    };
    trackEvent('IdV: camera info logged', logInfo);
  } catch (err) {
    trackEvent('IdV: camera info error');
  }
}

async function logCameraInfo(trackEvent) {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const videoDevices = devices.filter((device) => device.kind === 'videoinput');
  videoDevices.forEach((videoDevice) => {
    updateConstraintsAndGetInfo(videoDevice, 'user', trackEvent);
    updateConstraintsAndGetInfo(videoDevice, 'environment', trackEvent);
  });
}

function useLogCameraInfo(isBackOfId, hasStartedCropping) {
  const [didLogCameraInfo, setDidLogCameraInfo] = useState(false);
  const { trackEvent } = useContext(AnalyticsContext);

  useEffect(() => {
    if (!isBackOfId) {
      return;
    }
    if (hasStartedCropping && !didLogCameraInfo) {
      logCameraInfo(trackEvent);
      setDidLogCameraInfo(true);
    }
  }, [didLogCameraInfo, hasStartedCropping, isBackOfId, trackEvent]);
}

export { useLogCameraInfo };
