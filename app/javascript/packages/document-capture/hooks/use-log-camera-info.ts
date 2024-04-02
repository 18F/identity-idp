import { useEffect, useContext, useRef } from 'react';
import AnalyticsContext from '../context/analytics';

type TrackEventType = (event: string, payload?: object | undefined) => void;
interface CameraLog {
  label: string;
  frameRate: number | undefined;
  height: number | undefined;
  width: number | undefined;
}
type CameraLogs = (CameraLog | undefined)[];

function getConstraints(deviceId: string) {
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

function getCameraInfo(videoTrack: MediaStreamTrack) {
  const cameraInfo = {
    label: videoTrack.label,
    frameRate: videoTrack.getSettings().frameRate,
    height: videoTrack.getSettings().height,
    width: videoTrack.getSettings().width,
  };
  return cameraInfo;
}

async function updateConstraintsAndGetLogInfo(
  videoDevice: MediaDeviceInfo,
  trackEvent: TrackEventType,
) {
  // See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints/facingMode
  const updatedConstraints = getConstraints(videoDevice.deviceId);
  try {
    const stream = await navigator.mediaDevices.getUserMedia(updatedConstraints);
    const videoTracks = stream.getVideoTracks();
    const cameras = videoTracks.map((videoTrack) => getCameraInfo(videoTrack));
    return cameras[0];
  } catch (error) {
    trackEvent('idv_camera_info_error', { error });
  }
}

function logsHaveSameValuesButDifferentName(logOne: CameraLog, logTwo: CameraLog) {
  if (
    logOne.height === logTwo.height &&
    logOne.width === logTwo.width &&
    logOne.frameRate === logTwo.frameRate
  ) {
    return true;
  }
  return false;
}

function condenseCameraLogs(cameraLogs: CameraLogs) {
  // Group logs into sets based on height/width/framerate and return one log for each
  // Go from this:
  // [
  //  { label: 'Front Camera',          height: 3024, width: 4032, frameRate: 30}]
  //  { label: 'Back Triple Camera',    height: 3024, width: 4032, frameRate: 30}]
  //  { label: 'Back Dual Wide Camera', height: 3024, width: 4032, frameRate: 30}]
  // ]
  // To this:
  // [{ label: 'Front Camera, Back Triple Camera, Back Dual Wide Camera', height: 3024, width: 4032, frameRate: 30}]
  const initialArray: CameraLog[] = [];
  const condensedLogs = cameraLogs.reduce((accumulator, currentLog) => {
    for (let i = 0; i < accumulator.length; i++) {
      const recordedLog: CameraLog = accumulator[i];
      if (currentLog && logsHaveSameValuesButDifferentName(currentLog, recordedLog)) {
        // Append to the label field for that log in condensed logs
        const newLabel = `${recordedLog.label}, ${currentLog.label}`;
        accumulator[i].label = newLabel;
        return accumulator;
      }
    }
    // Add a new log to condensed logs, when it doesn't match the existing ones
    if (currentLog) {
      return accumulator.concat(currentLog);
    }
    return accumulator;
  }, initialArray);
  return condensedLogs;
}

async function logCameraInfo(trackEvent: TrackEventType) {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const videoDevices = devices.filter((device) => device.kind === 'videoinput');
  const cameraLogs = await Promise.all(
    videoDevices.map((videoDevice) => updateConstraintsAndGetLogInfo(videoDevice, trackEvent)),
  );
  const condensedCameraLogs = condenseCameraLogs(cameraLogs);
  trackEvent('idv_camera_info_logged', { camera_info: condensedCameraLogs });
}

// This function is intended to be used only after camera permissions have been granted
// hasStartedCropping only happens after an image has been captured with the Acuant SDK,
// which means that camera permissions have been granted.
function useLogCameraInfo({
  isBackOfId,
  hasStartedCropping,
}: {
  isBackOfId: boolean;
  hasStartedCropping: boolean;
}) {
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
