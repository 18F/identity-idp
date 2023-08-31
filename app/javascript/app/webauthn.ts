interface EnrollResult {
  webauthnId: string;

  webauthnPublicKey: string;

  attestationObject: string;

  clientDataJSON: string;
}

interface VerifyResult {
  credentialId: string;

  authenticatorData: string;

  clientDataJSON: string;

  signature: string;
}

const base64ToArrayBuffer = (base64: string): ArrayBuffer => {
  const bytes = Uint8Array.from(
    window
      .atob(base64)
      .split('')
      .map((char) => char.charCodeAt(0)),
  );
  return bytes.buffer;
};

const arrayBufferToBase64 = (arrayBuffer: ArrayBuffer): string => {
  const buffer = new Uint8Array(arrayBuffer);
  const binaryString = Array.from(buffer)
    .map((byte) => String.fromCharCode(byte))
    .join('');
  return window.btoa(binaryString);
};

const longToByteArray = (long: number): Uint8Array =>
  new Uint8Array(8).map(() => {
    const byte = long & 0xff; // eslint-disable-line no-bitwise
    long = (long - byte) / 256;
    return byte;
  });

const extractCredentials = (credentials: string): PublicKeyCredentialDescriptor[] => {
  if (!credentials) {
    // empty string check
    return [];
  }
  return credentials.split(',').map((credential) => ({
    type: 'public-key',
    id: base64ToArrayBuffer(credential),
  }));
};

const enrollWebauthnDevice = async ({
  userId,
  userEmail,
  userChallenge,
  excludeCredentials,
  platformAuthenticator,
}: {
  userId: string;
  userEmail: string;
  userChallenge: string;
  excludeCredentials: string;
  platformAuthenticator: boolean;
}): Promise<EnrollResult> => {
  const newCred = (await navigator.credentials.create({
    publicKey: {
      challenge: new Uint8Array(JSON.parse(userChallenge)),
      rp: { name: window.location.hostname },
      user: {
        id: longToByteArray(Number(userId)),
        name: userEmail,
        displayName: userEmail,
      },
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
        authenticatorAttachment: platformAuthenticator ? 'platform' : 'cross-platform',
      },
      excludeCredentials: extractCredentials(excludeCredentials),
    },
  })) as PublicKeyCredential;

  const response = newCred.response as AuthenticatorAttestationResponse;

  return {
    webauthnId: arrayBufferToBase64(newCred.rawId),
    webauthnPublicKey: newCred.id,
    attestationObject: arrayBufferToBase64(response.attestationObject),
    clientDataJSON: arrayBufferToBase64(response.clientDataJSON),
  };
};

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
      allowCredentials: extractCredentials(credentialIds),
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

export { extractCredentials, enrollWebauthnDevice, verifyWebauthnDevice };
