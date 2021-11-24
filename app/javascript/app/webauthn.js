const base64ToArrayBuffer = (base64) => {
  const bytes = Uint8Array.from(
    window
      .atob(base64)
      .split('')
      .map((char) => char.charCodeAt(0)),
  );
  return bytes.buffer;
};

const arrayBufferToBase64 = (arrayBuffer) => {
  const buffer = new Uint8Array(arrayBuffer);
  const binaryString = Array.from(buffer)
    .map((byte) => String.fromCharCode(byte))
    .join('');
  return window.btoa(binaryString);
};

const longToByteArray = (long) =>
  new Uint8Array(8).map(() => {
    const byte = long & 0xff; // eslint-disable-line no-bitwise
    long = (long - byte) / 256;
    return byte;
  });

const extractCredentials = (credentials) => {
  if (!credentials) {
    // empty string check
    return [];
  }
  return credentials.split(',').map((credential) => ({
    type: 'public-key',
    id: base64ToArrayBuffer(credential),
  }));
};

const isWebAuthnEnabled = () => {
  if (navigator && navigator.credentials && navigator.credentials.create) {
    return true;
  }
  return false;
};

const enrollWebauthnDevice = ({ userId, userEmail, userChallenge, excludeCredentials, platformAuthenticator }) => {
  const createOptions = {
    publicKey: {
      challenge: new Uint8Array(JSON.parse(userChallenge)),
      rp: { name: window.location.hostname },
      user: {
        id: longToByteArray(userId),
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
      excludeList: [],
      authenticatorSelection: {
        // Prevents user from needing to use PIN with Security Key
        userVerification: 'discouraged',
        authenticatorAttachment: platformAuthenticator ? 'platform' : 'cross-platform',
      },
      excludeCredentials: extractCredentials(excludeCredentials),
    },
  };

  return navigator.credentials.create(createOptions).then((newCred) => ({
    webauthnId: arrayBufferToBase64(newCred.rawId),
    webauthnPublicKey: newCred.id,
    attestationObject: arrayBufferToBase64(newCred.response.attestationObject),
    clientDataJSON: arrayBufferToBase64(newCred.response.clientDataJSON),
  }));
};

const verifyWebauthnDevice = ({ userChallenge, credentialIds }) => {
  const getOptions = {
    publicKey: {
      challenge: new Uint8Array(JSON.parse(userChallenge)),
      rpId: window.location.hostname,
      allowCredentials: extractCredentials(credentialIds),
      timeout: 800000,
    },
  };

  return navigator.credentials.get(getOptions).then((newCred) => ({
    credentialId: arrayBufferToBase64(newCred.rawId),
    authenticatorData: arrayBufferToBase64(newCred.response.authenticatorData),
    clientDataJSON: arrayBufferToBase64(newCred.response.clientDataJSON),
    signature: arrayBufferToBase64(newCred.response.signature),
  }));
};

export { extractCredentials, isWebAuthnEnabled, enrollWebauthnDevice, verifyWebauthnDevice };
