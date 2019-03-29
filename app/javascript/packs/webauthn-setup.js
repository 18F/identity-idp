const WebAuthn = require('../app/webauthn');

function webauthn() {
  if (location.href.indexOf('?error=') === -1 && !WebAuthn.isWebAuthnEnabled()) {
    window.location.href = '/webauthn_setup?error=NotSupportedError';
  }
  const continueButton = document.getElementById('continue-button');
  continueButton.addEventListener('click', () => {
    document.getElementById('spinner').className = '';
    document.getElementById('continue-button').className = 'hidden';

    WebAuthn.enrollWebauthnDevice({
      userId: document.getElementById('user_id').value,
      userEmail: document.getElementById('user_email').value,
      userChallenge: document.getElementById('user_challenge').value,
      excludeCredentials: document.getElementById('exclude_credentials').value,
    }).then((result) => {
      document.getElementById('webauthn_id').value = result.webauthnId;
      document.getElementById('webauthn_public_key').value = result.webauthnPublicKey;
      document.getElementById('attestation_object').value = result.attestationObject;
      document.getElementById('client_data_json').value = result.clientDataJSON;
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
