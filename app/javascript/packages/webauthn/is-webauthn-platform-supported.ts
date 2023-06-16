export type IsWebauthnPlatformSupported = () => Promise<boolean>;

const isWebauthnPlatformSupported: IsWebauthnPlatformSupported = async () =>
  !!(await window.PublicKeyCredential?.isUserVerifyingPlatformAuthenticatorAvailable());

export default isWebauthnPlatformSupported;
