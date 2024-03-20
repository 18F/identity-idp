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
      facingMode,
      cameraInfo: cameras,
    };
    console.log(logInfo);
    trackEvent('IdV: camera resolution logged', logInfo);
  } catch (err) {
    // TODO Log an error
  }
}

async function logDeviceResolution(trackEvent) {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const videoDevices = devices.filter((device) => device.kind === 'videoinput');
  videoDevices.map((videoDevice) => {
    updateConstraintsAndGetInfo(videoDevice, 'user', trackEvent);
    updateConstraintsAndGetInfo(videoDevice, 'environment', trackEvent);
    return true;
  });
}

export { logDeviceResolution };
