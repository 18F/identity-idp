import { arrayBufferToBase64 } from './converters';
import extractCredentials from './extract-credentials';

interface VerifyOptions {
  userChallenge: string;

  credentialIds: string;
}

interface VerifyResult {
  credentialId: string;

  authenticatorData: string;

  clientDataJSON: string;

  signature: string;
}

async function verifyWebauthnDevice({
  userChallenge,
  credentialIds,
}: VerifyOptions): Promise<VerifyResult> {
  const credential = (await navigator.credentials.get({
    publicKey: {
      challenge: new Uint8Array(JSON.parse(userChallenge)),
      rpId: window.location.hostname,
      allowCredentials: extractCredentials(credentialIds.split(',').filter(Boolean)),
      timeout: 800000,
    },
  })) as PublicKeyCredential;

  const response = credential.response as AuthenticatorAssertionResponse;

  return {
    credentialId: arrayBufferToBase64(credential.rawId),
    authenticatorData: arrayBufferToBase64(response.authenticatorData),
    clientDataJSON: arrayBufferToBase64(response.clientDataJSON),
    signature: arrayBufferToBase64(response.signature),
  };
}

export default verifyWebauthnDevice;
