import { extractCredentials, arrayBufferToBase64 } from '@18f/identity-webauthn';

interface VerifyResult {
  credentialId: string;

  authenticatorData: string;

  clientDataJSON: string;

  signature: string;
}

async function verifyWebauthnDevice({
  userChallenge,
  credentialIds,
}: {
  userChallenge: string;
  credentialIds: string;
}): Promise<VerifyResult> {
  const getOptions = {
    publicKey: {
      challenge: new Uint8Array(JSON.parse(userChallenge)),
      rpId: window.location.hostname,
      allowCredentials: extractCredentials(credentialIds.split(',').filter(Boolean)),
      timeout: 800000,
    },
  };

  const newCred = (await navigator.credentials.get(getOptions)) as PublicKeyCredential;

  const response = newCred.response as AuthenticatorAssertionResponse;

  return {
    credentialId: arrayBufferToBase64(newCred.rawId),
    authenticatorData: arrayBufferToBase64(response.authenticatorData),
    clientDataJSON: arrayBufferToBase64(response.clientDataJSON),
    signature: arrayBufferToBase64(response.signature),
  };
}

export { verifyWebauthnDevice };
