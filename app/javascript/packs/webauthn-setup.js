function webauthn() {
  const arrayBufferToBase64 = function(buffer) {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    const len = bytes.byteLength;
    for (let i = 0; i < len; i += 1) {
      binary += String.fromCharCode(bytes[i]);
    }
    return window.btoa(binary);
  };
  const longToByteArray = function(long) {
    const byteArray = new Uint8Array(8);
    for (let index = 0; index < byteArray.length; index += 1) {
      const byte = long & 0xff;  // eslint-disable-line no-bitwise
      byteArray[index] = byte;
      long = (long - byte) / 256;
    }
    return byteArray;
  };
  const userId = document.getElementById('user_id').value;
  const userEmail = document.getElementById('user_email').value;
  const challengeBytes = new Uint8Array(JSON.parse(document.getElementById('user_challenge').value));
  const createOptions = {
    publicKey: {
      challenge: challengeBytes,
      rp: { name: window.location.hostname },
      user: {
        id: longToByteArray(userId),
        name: userEmail,
        displayName: userEmail,
      },
      pubKeyCredParams: [
        {
          type: 'public-key',
          alg: -7,
        },
      ],
      timeout: 800000,
      attestation: 'none',
      excludeList: [],
    },
  };
  const continueButton = document.getElementById('continue-button');
  continueButton.addEventListener('click', () => {
    document.getElementById('spinner').className = '';
    document.getElementById('continue-button').className = 'hidden';
    const p = navigator.credentials.create(createOptions);
    p.then((newCred) => {
      document.getElementById('webauthn_id').value = arrayBufferToBase64(newCred.rawId);
      document.getElementById('webauthn_public_key').value = newCred.id;
      document.getElementById('attestation_object').value = arrayBufferToBase64(newCred.response.attestationObject);
      document.getElementById('client_data_json').value = arrayBufferToBase64(newCred.response.clientDataJSON);
      document.getElementById('webauthn_form').submit();
    });
  });
}
document.addEventListener('DOMContentLoaded', webauthn);
