const WebAuthn = require('../app/webauthn');

function webauthn() {
  // If webauthn is not supported redirect back to the 2fa options list
  if (!WebAuthn.isWebAuthnEnabled()) {
    window.location.href = '/login/two_factor/options';
  }

  const webauthnInProgressContainer = document.getElementById('webauthn-auth-in-progress');
  const webauthnSuccessContainer = document.getElementById('webauthn-auth-successful');

  WebAuthn.verifyWebauthnDevice({
    userChallenge: document.getElementById('user_challenge').value,
    credentialIds: document.getElementById('credential_ids').value,
  }).then((result) => {
    document.getElementById('credential_id').value = result.credentialId;
    document.getElementById('authenticator_data').value = result.authenticatorData;
    document.getElementById('client_data_json').value = result.clientDataJSON;
    document.getElementById('signature').value = result.signature;
    webauthnInProgressContainer.classList.add('hidden');
    webauthnSuccessContainer.classList.remove('hidden');
  });
}
document.addEventListener('DOMContentLoaded', webauthn);
