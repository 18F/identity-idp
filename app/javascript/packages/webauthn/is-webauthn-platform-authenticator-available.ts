export type IsWebauthnPlatformAvailable = () => Promise<boolean>;

const isWebauthnPlatformAuthenticatorAvailable: IsWebauthnPlatformAvailable = async () =>
  !!(await window.PublicKeyCredential?.isUserVerifyingPlatformAuthenticatorAvailable());

export default isWebauthnPlatformAuthenticatorAvailable;
