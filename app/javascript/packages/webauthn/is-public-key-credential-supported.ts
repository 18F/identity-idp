async function isPublicKeyCredentialSupported(): Promise<boolean> {
  const isUserVerifyingPlatformAuthenticatorAvailable =
    await window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
  return window.PublicKeyCredential && isUserVerifyingPlatformAuthenticatorAvailable;
}

export default isPublicKeyCredentialSupported;
