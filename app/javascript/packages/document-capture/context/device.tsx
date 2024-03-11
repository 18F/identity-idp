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
    // TODO log that the camera resolution check failed
  }
}

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
  videoTrack.stop();
  return cameraInfo;
}

async function updateConstraintsAndGetInfo(videoDevice) {
  // See https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints/facingMode
  const facingMode = 'user';
  const updatedConstraints = getConstraints(videoDevice.deviceId, facingMode);
  try {
    const stream = await navigator.mediaDevices.getUserMedia(updatedConstraints);
    const videoTracks = stream.getVideoTracks();
    const cameras = videoTracks.map((videoTrack) => getCameraInfo(videoTrack));
    console.log(cameras);
  } catch (err) {
    // TODO Log an error
  }
}

async function getDeviceInfo() {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const videoDevices = devices.filter((device) => device.kind === 'videoinput');
  videoDevices.map((videoDevice) => updateConstraintsAndGetInfo(videoDevice));
}

function DeviceContextProvider({ isMobile, children }: DeviceContextValue) {
  const detectCameraResolution = async () => {
    if (await navigator.mediaDevices.getUserMedia()) {
      if (await videoTracksAvailable()) {
        getDeviceInfo();
      }
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
