function webauthn() {
  const base64ToArrayBuffer = function(base64) {
    const binaryString = window.atob(base64);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i += 1) {
      bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes.buffer;
  };
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
  const excludeCredentialsString = document.getElementById('exclude_credentials').value;
  const excludeCredentialsArray = [];
  if (excludeCredentialsString) {
    const arr = excludeCredentialsString.split(',');
    for (let i = 0; i < arr.length; i += 1) {
      excludeCredentialsArray.push({
        type: 'public-key',
        id: base64ToArrayBuffer(arr[i]),
      });
    }
  }
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
          alg: -7, // ECDSA w/ SHA-256
        },
        {
          type: 'public-key',
          alg: -8, // EdDSA
        },
        {
          type: 'public-key',
          alg: -35, // ECDSA w/SHA-384
        },
      ],
      timeout: 800000,
      attestation: 'none',
      excludeList: [],
      excludeCredentials: excludeCredentialsArray,
    },
  };
  if (!(navigator && navigator.credentials && navigator.credentials.create)) {
    window.location.href = '/webauthn_setup?error=NotSupportedError';
  }
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
    }).catch(function (err) {
      window.location.href = `/webauthn_setup?error=${err.name}`;
    });
  });
  const input = document.getElementById('nickname');
  input.addEventListener('keypress', function(event) {
    if (event.keyCode === 13) {
      // prevent form submit
      event.preventDefault();
    }
  });
  input.addEventListener('keyup', function(event) {
    event.preventDefault();
    if (event.keyCode === 13 && input.value) {
      continueButton.click();
    }
  });
}
document.addEventListener('DOMContentLoaded', webauthn);
