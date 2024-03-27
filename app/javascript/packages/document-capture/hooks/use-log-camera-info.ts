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
    return cameras[0];
  } catch (error) {
    trackEvent('idv_camera_info_error');
  }
}

function logsHaveSameValuesButDifferentName(logOne, logTwo) {
  if (
    logOne.height === logTwo.height &&
    logOne.width === logTwo.width &&
    logOne.frameRate === logTwo.frameRate
  ) {
    return true;
  }
  return false;
}

function condenseLogs(logs) {
  // Okay, so the goal is to group logs into sets based on height/width/framerate
  const condensedLogs = logs.reduce((accumulator, currentLog) => {
    for (let i = 0; i < accumulator.length; i++) {
      const recordedLog = accumulator[i];
      if (logsHaveSameValuesButDifferentName(currentLog, recordedLog)) {
        // Append to the label field for that log in condensed logs
        const newLabel = `${recordedLog.label}, ${currentLog.label}`;
        accumulator[i].label = newLabel;
        return accumulator;
      }
    }
    // Add that log to condensed logs
    return accumulator.concat(currentLog);
  }, []);
  return condensedLogs;
}

async function logCameraInfo(trackEvent) {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const videoDevices = devices.filter((device) => device.kind === 'videoinput');
  const logs = await Promise.all(
    videoDevices.map((videoDevice) => updateConstraintsAndLogInfo(videoDevice, trackEvent)),
  );
  const condensedLogs = condenseLogs(logs);
  console.log(condensedLogs);
  trackEvent('idv_camera_info_logged', { camera_info: condensedLogs });
}

// This function is intended to be used only after camera permissions have been granted
// hasStartedCropping only happens after an image has been captured with the Acuant SDK,
// which means that camera permissions have been granted.
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
