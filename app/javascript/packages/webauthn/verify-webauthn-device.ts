import { base64ToArrayBuffer, arrayBufferToBase64 } from '@18f/identity-webauthn';

export interface VerifyCredentialDescriptor {
  id: string;

  transports: null | AuthenticatorTransport[];
}

interface VerifyOptions {
  userChallenge: string;

  credentials: VerifyCredentialDescriptor[];
}

interface VerifyResult {
  credentialId: string;

  authenticatorData: string;

  clientDataJSON: string;

  signature: string;
}

const mapVerifyCredential = (
  credential: VerifyCredentialDescriptor,
): PublicKeyCredentialDescriptor => ({
  type: 'public-key',
  id: base64ToArrayBuffer(credential.id),
  transports: credential.transports || undefined,
});

async function verifyWebauthnDevice({
  userChallenge,
  credentials,
}: VerifyOptions): Promise<VerifyResult> {
  const credential = (await navigator.credentials.get({
    publicKey: {
      challenge: new Uint8Array(JSON.parse(userChallenge)),
      rpId: window.location.hostname,
      allowCredentials: credentials.map(mapVerifyCredential),
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
