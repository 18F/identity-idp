import { arrayBufferToBase64 } from './converters';

interface EnrollOptions {
  user: PublicKeyCredentialUserEntity;

  challenge: BufferSource;

  excludeCredentials: PublicKeyCredentialDescriptor[];

  authenticatorAttachment?: AuthenticatorAttachment;
}

interface EnrollResult {
  webauthnId: string;

  webauthnPublicKey: string;

  attestationObject: string;

  clientDataJSON: string;
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

  const response = credential.response as AuthenticatorAttestationResponse;

  return {
    webauthnId: arrayBufferToBase64(credential.rawId),
    webauthnPublicKey: credential.id,
    attestationObject: arrayBufferToBase64(response.attestationObject),
    clientDataJSON: arrayBufferToBase64(response.clientDataJSON),
  };
}

export default enrollWebauthnDevice;
