export type IsWebauthnPasskeySupported = () => boolean;

const MINIMUM_IOS_VERSION = 16;

const MINIMUM_ANDROID_VERSION = 9;

function isQualifyingIOSDevice(): boolean {
  const match = navigator.userAgent.match(/iPhone; CPU iPhone OS (\d+)_/);
  const iOSVersion: null | number = match && Number(match[1]);
  return !!iOSVersion && iOSVersion >= MINIMUM_IOS_VERSION;
}

function isQualifyingAndroidDevice(): boolean {
  // Note: Chrome versions applying the "reduced" user agent string will always report a version of
  // Android as 10.0.0.
  //
  // See: https://www.chromium.org/updates/ua-reduction/
  const match = navigator.userAgent.match(/; Android (\d+)/);
  const androidVersion: null | number = match && Number(match[1]);
  return (
    !!androidVersion &&
    androidVersion >= MINIMUM_ANDROID_VERSION &&
    navigator.userAgent.includes(' Chrome/')
  );
}

function isCredentialSupported(): boolean {
  return this.window.PasswordCredential || this.window.FederatedCredential
}

const isWebauthnPasskeySupported: IsWebauthnPasskeySupported = () =>
  (isQualifyingIOSDevice() || isQualifyingAndroidDevice()) && isCredentialSupported() ;

export default isWebauthnPasskeySupported;
