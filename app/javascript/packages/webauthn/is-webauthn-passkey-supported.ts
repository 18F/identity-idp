export type IsWebauthnPasskeySupported = () => boolean;

const MINIMUM_IOS_VERSION = 16;

const MINIMUM_ANDROID_VERSION = 9;

const MINIMUM_MACOS_VERSION = 13;

const MINIMUM_WINDOWS_VERSION = 10

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

function isQualifyingMacOSDesktopDevice(): boolean {
  const match = navigator.userAgent.match(/Mac OS X/);
  const macOsVersion: null | number = match && Number(match[1]);
  return !!macOsVersion && macOsVersion >= MINIMUM_MACOS_VERSION;
}

function isQualifyingWindowsDesktopDevice(): boolean {
  const match = navigator.userAgent.match(/Windows/);
  const windowsVersion: null | number = match && Number(match[1]);
  return !!windowsVersion && windowsVersion >= MINIMUM_WINDOWS_VERSION;
}

const isWebauthnPasskeySupported: IsWebauthnPasskeySupported = () =>
  isQualifyingIOSDevice() || isQualifyingAndroidDevice() 
  || isQualifyingMacOSDesktopDevice() || isQualifyingWindowsDesktopDevice();

export default isWebauthnPasskeySupported;
