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
  // If webauthn is not supported redirect back to the 2fa options list
  if (!(navigator && navigator.credentials && navigator.credentials.create)) {
    window.location.href = '/login/two_factor/options';
  }
  const challengeBytes = new Uint8Array(JSON.parse(document.getElementById('user_challenge').value));
  let credentialIds = document.getElementById('credential_ids').value;
  credentialIds = credentialIds.split(',');
  const allowCredentials2 = [];
  credentialIds.forEach(function(credentialId) {
    allowCredentials2.push({
      type: 'public-key',
      id: base64ToArrayBuffer(credentialId),
    });
  });
  const getOptions = {
    publicKey: {
      challenge: challengeBytes,
      rpId: window.location.hostname,
      allowCredentials: allowCredentials2,
      timeout: 800000,
    },
  };
  const p = navigator.credentials.get(getOptions);
  p.then((newCred) => {
    document.getElementById('credential_id').value = arrayBufferToBase64(newCred.rawId);
    document.getElementById('authenticator_data').value = arrayBufferToBase64(newCred.response.authenticatorData);
    document.getElementById('client_data_json').value = arrayBufferToBase64(newCred.response.clientDataJSON);
    document.getElementById('signature').value = arrayBufferToBase64(newCred.response.signature);
    document.getElementById('webauthn_form').submit();
  });
}
document.addEventListener('DOMContentLoaded', webauthn);
