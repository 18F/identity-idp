export type isWebauthnPlatformAvailable = () => Promise<boolean>;

const isWebauthnPlatformAuthenticatorAvailable: isWebauthnPlatformAvailable = async () =>
  !!(await window.PublicKeyCredential?.isUserVerifyingPlatformAuthenticatorAvailable());

export default isWebauthnPlatformAuthenticatorAvailable;
