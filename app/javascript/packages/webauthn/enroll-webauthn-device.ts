import { arrayBufferToBase64 } from './converters';

/**
 * Response object with properties as possibly undefined where browser support varies.
 *
 * As of writing, Firefox does not implement getTransports or getAuthenticatorData. Remove this if
 * and when support changes.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/API/AuthenticatorAttestationResponse/getTransports#browser_compatibility
 * @see https://developer.mozilla.org/en-US/docs/Web/API/AuthenticatorAttestationResponse/getAuthenticatorData#browser_compatibility
 */
interface AuthenticatorAttestationResponseBrowserSupport
  extends Omit<AuthenticatorAttestationResponse, 'getAuthenticatorData' | 'getTransports'> {
  getTransports: AuthenticatorAttestationResponse['getTransports'] | undefined;
  getAuthenticatorData: AuthenticatorAttestationResponse['getAuthenticatorData'] | undefined;
}

interface EnrollOptions {
  user: PublicKeyCredentialUserEntity;

  challenge: BufferSource;

  excludeCredentials: PublicKeyCredentialDescriptor[];

  authenticatorAttachment?: AuthenticatorAttachment;
}

interface EnrollResult {
  webauthnId: string;

  attestationObject: string;

  clientDataJSON: string;

  authenticatorDataFlagsValue?: number;

  transports?: string[];
}

async function enrollWebauthnDevice({
  user,
  challenge,
  excludeCredentials,
  authenticatorAttachment,
}: EnrollOptions): Promise<EnrollResult> {
  const credential = (await navigator.credentials.create({
    publicKey: {
      challenge,
      rp: { name: window.location.hostname },
      user,
      pubKeyCredParams: [
        {
          type: 'public-key',
          alg: -7, // ECDSA w/ SHA-256
        },
        {
          type: 'public-key',
          alg: -35, // ECDSA w/ SHA-384
        },
        {
          type: 'public-key',
          alg: -36, // ECDSA w/ SHA-512
        },
        {
          type: 'public-key',
          alg: -37, // RSASSA-PSS w/ SHA-256
        },
        {
          type: 'public-key',
          alg: -38, // RSASSA-PSS w/ SHA-384
        },
        {
          type: 'public-key',
          alg: -39, // RSASSA-PSS w/ SHA-512
        },
        {
          type: 'public-key',
          alg: -257, // RSASSA-PKCS1-v1_5 w/ SHA-256
        },
      ],
      timeout: 800000,
      attestation: 'none',
      authenticatorSelection: {
        // Prevents user from needing to use PIN with Security Key
        userVerification: 'discouraged',
        authenticatorAttachment,
      },
      excludeCredentials,
    },
  })) as PublicKeyCredential;

  const response = credential.response as AuthenticatorAttestationResponseBrowserSupport;
  const authenticatorData = response.getAuthenticatorData?.();
  const authenticatorDataFlagsValue = authenticatorData
    ? new Uint8Array(authenticatorData)[32]
    : undefined;

  return {
    webauthnId: arrayBufferToBase64(credential.rawId),
    attestationObject: arrayBufferToBase64(response.attestationObject),
    clientDataJSON: arrayBufferToBase64(response.clientDataJSON),
    authenticatorDataFlagsValue,
    transports: response.getTransports?.(),
  };
}

export default enrollWebauthnDevice;
