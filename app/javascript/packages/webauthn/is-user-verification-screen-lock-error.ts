/**
 * @see https://source.chromium.org/chromium/chromium/src/+/main:third_party/blink/renderer/modules/credentialmanagement/credentials_container.cc;l=432;drc=6d16761b175fd105f879a4e1803547381e97402d
 */
export const SCREEN_LOCK_ERROR =
  'The specified `userVerification` requirement cannot be fulfilled by this device unless the device is secured with a screen lock.';

const isUserVerificationScreenLockError = (error: Error): boolean =>
  error.message === SCREEN_LOCK_ERROR;

export default isUserVerificationScreenLockError;
