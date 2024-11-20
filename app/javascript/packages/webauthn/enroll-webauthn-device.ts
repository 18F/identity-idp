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

type PublicKeyCredentialHintType = 'client-device' | 'security-key' | 'hybrid';

interface EnrollOptions {
  platformAuthenticator?: boolean;

  user: PublicKeyCredentialUserEntity;

  challenge: BufferSource;

  excludeCredentials: PublicKeyCredentialDescriptor[];
}

interface EnrollResult {
  webauthnId: string;

  attestationObject: string;

  clientDataJSON: string;

  authenticatorDataFlagsValue?: number;

  transports?: string[];
}

interface PublicKeyCredentialCreationOptionsWithHints extends PublicKeyCredentialCreationOptions {
  hints?: Array<PublicKeyCredentialHintType>;
}

/**
 * All possible algorithms supported within the CBOR Object Signing and Encryption (COSE) format.
 *
 * For practicality's sake, this is not a complete list, and is currently limited to the algorithms
 * referenced within the supported algorithms below.
 *
 * @see https://www.iana.org/assignments/cose/cose.xhtml#algorithms
 */
const enum COSEAlgorithm {
  ES256 = -7,
  ES384 = -35,
  ES512 = -36,
  PS256 = -37,
  PS384 = -38,
  PS512 = -39,
  RS256 = -257,
}

/**
 * The subset of possible COSE algorithms supported for use in WebAuthn enrollments.
 *
 * @see https://github.com/18F/identity-idp/blob/main/config/initializers/webauthn.rb
 * @see https://github.com/cedarcode/webauthn-ruby/blob/6db9596/lib/webauthn/relying_party.rb#L16
 */
const SUPPORTED_ALGORITHMS: COSEAlgorithm[] = [
  COSEAlgorithm.ES256,
  COSEAlgorithm.ES384,
  COSEAlgorithm.ES512,
  COSEAlgorithm.PS256,
  COSEAlgorithm.PS384,
  COSEAlgorithm.PS512,
  COSEAlgorithm.RS256,
];

async function enrollWebauthnDevice({
  platformAuthenticator = false,
  user,
  challenge,
  excludeCredentials,
}: EnrollOptions): Promise<EnrollResult> {
  const credential = (await navigator.credentials.create({
    publicKey: {
      challenge,
      rp: { name: window.location.hostname },
      user,
      pubKeyCredParams: SUPPORTED_ALGORITHMS.map((alg) => ({ alg, type: 'public-key' })),
      timeout: 800000,
      attestation: 'none',
      hints: platformAuthenticator ? undefined : ['security-key'],
      authenticatorSelection: {
        // A user is assumed to be AAL2 recently authenticated before being permitted to add an
        // authentication method to their account. Additionally, unless explicitly discouraged,
        // Windows devices will prompt the user to add a PIN to their security key. When used as a
        // single-factor authenticator in combination with a memorized secret (password), proving
        // possession is sufficient, and a PIN ("something you know") is unnecessary friction that
        // contributes to abandonment or loss of access.
        userVerification: 'discouraged',
        authenticatorAttachment: platformAuthenticator ? 'platform' : 'cross-platform',
        residentKey: platformAuthenticator ? 'preferred' : undefined,
      },
      excludeCredentials,
    } as PublicKeyCredentialCreationOptionsWithHints,
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
