import { createContext, ReactNode } from 'react';
import { useObjectMemo } from '@18f/identity-react-hooks';

export interface DeviceContextValue {
  children: ReactNode;
  isMobile: boolean;
}

const DeviceContext = createContext({
  isMobile: false,
  detectCameraResolution: () => {},
});

DeviceContext.displayName = 'DeviceContext';

async function videoTracksAvailable() {
  // Check that there are tracks in the device, also stop them?
  try {
    const first = await navigator.mediaDevices.getUserMedia({ video: true });
    first.getTracks().forEach((track) => track.stop());
    return true;
  } catch (err) {
    // Probably log that the camera resolution check failed
  }
}

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
  videoTrack.stop();
  return cameraInfo;
}

async function updateConstraintsAndGetInfo(videoDevice) {
  const updatedConstraints = getConstraints(videoDevice.deviceId);
  try {
    const stream = await navigator.mediaDevices.getUserMedia(updatedConstraints);
    const videoTracks = stream.getVideoTracks();
    const cameras = videoTracks.map((videoTrack) => getCameraInfo(videoTrack));
    // I get an object here, but unresolved promises everywhere else
    return cameras;
  } catch (err) {
    // Log an error
  }
}

async function getDeviceInfo() {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const videoDevices = devices.filter((device) => device.kind === 'videoinput');
  const info = videoDevices.map((videoDevice) => updateConstraintsAndGetInfo(videoDevice));
  return info;
}

function DeviceContextProvider({ isMobile, children }: DeviceContextValue) {
  const detectCameraResolution = async () => {
    if (navigator?.mediaDevices?.getUserMedia) {
      const available = await videoTracksAvailable();
      const info = await getDeviceInfo();
    }
  };

  const value = useObjectMemo({
    isMobile,
    detectCameraResolution,
  });

  return <DeviceContext.Provider value={value}>{children}</DeviceContext.Provider>;
}

export default DeviceContext;
export { DeviceContextProvider as Provider };
