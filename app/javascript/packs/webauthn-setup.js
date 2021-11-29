import { loadPolyfills } from '@18f/identity-polyfill';
import { isWebAuthnEnabled, enrollWebauthnDevice } from '../app/webauthn';

/**
 * Reloads the current page, presenting the message corresponding to the given error key.
 *
 * @param {string} error Error key for which to show message.
 */
function reloadWithError(error) {
  const params = new URLSearchParams(window.location.search);
  params.set('error', error);
  window.location.search = params.toString();
}

function webauthn() {
  if (window.location.href.indexOf('?error=') === -1 && !isWebAuthnEnabled()) {
    reloadWithError('NotSupportedError');
  }
  const continueButton = document.getElementById('continue-button');
  continueButton.addEventListener('click', () => {
    document.getElementById('spinner').className = '';
    document.getElementById('continue-button').className = 'hidden';

    const platformAuthenticator =
      document.getElementById('platform_authenticator').value === 'true';

    enrollWebauthnDevice({
      userId: document.getElementById('user_id').value,
      userEmail: document.getElementById('user_email').value,
      userChallenge: document.getElementById('user_challenge').value,
      excludeCredentials: document.getElementById('exclude_credentials').value,
      platformAuthenticator,
    })
      .then((result) => {
        document.getElementById('webauthn_id').value = result.webauthnId;
        document.getElementById('webauthn_public_key').value = result.webauthnPublicKey;
        document.getElementById('attestation_object').value = result.attestationObject;
        document.getElementById('client_data_json').value = result.clientDataJSON;
        document.getElementById('webauthn_form').submit();
      })
      .catch((err) => reloadWithError(err.name));
  });
  const input = document.getElementById('nickname');
  input.addEventListener('keypress', function (event) {
    if (event.keyCode === 13) {
      // prevent form submit
      event.preventDefault();
    }
  });
  input.addEventListener('keyup', function (event) {
    event.preventDefault();
    if (event.keyCode === 13 && input.value) {
      continueButton.click();
    }
  });
}

loadPolyfills(['url']).then(webauthn);
