/**
 * Returns true if the device is likely a mobile device, or false otherwise. This is a rough
 * approximation, using device user agent sniffing.
 *
 * @return {boolean}
 */
export function isLikelyMobile() {
  return /ip(hone|ad|od)|android/i.test(window.navigator.userAgent);
}

/**
 * Returns true if the current device allows access to camera device APIs.
 *
 * @return {boolean}
 */
export function hasMediaAccess() {
  return !!navigator.mediaDevices;
}

/**
 * Returns a boolean promise of whether or not the device has a video input device.
 *
 * @return {Promise}
 */
export async function hasCamera() {
  if (hasMediaAccess()) {
    const devices = await navigator.mediaDevices.enumerateDevices();
    return devices.some((device) => device.kind === 'videoinput');
  }
}

/**
 * Returns true if the current device is assumed to be a mobile device where a camera is available,
 * or false otherwise. This is a rough approximation, using device user agent sniffing and
 * availability of camera device APIs.
 *
 * @return {boolean}
 */
export function isCameraCapableMobile() {
  return isLikelyMobile() && hasMediaAccess();
}
