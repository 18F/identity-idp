const WebAuthn = require('../app/webauthn');

async function webauthn() {
  // If webauthn is not supported redirect back to the 2fa options list
  const webauthnInProgressContainer = document.getElementById('webauthn-auth-in-progress');
  const webauthnSuccessContainer = document.getElementById('webauthn-auth-successful');

  const webauthnPlatformRequested =
    webauthnInProgressContainer.dataset.platformAuthenticatorRequested === 'true';
  const multipleFactorsEnabled =
    webauthnInProgressContainer.dataset.multipleFactorsEnabled === 'true';
  const webauthnPlatformEnabled = await window.PublicKeyCredential?.isUserVerifyingPlatformAuthenticatorAvailable();

  if (
    !WebAuthn.isWebAuthnEnabled() ||
    (webauthnPlatformRequested && !webauthnPlatformEnabled && !multipleFactorsEnabled)
  ) {
    const href = webauthnInProgressContainer.getAttribute('data-webauthn-not-enabled-url');
    window.location.href = href;
    return;
  }

  const spinner = document.getElementById('spinner');
  spinner.classList.remove('hidden');

  // if platform auth is not supported on device, we should take user to the error screen if theres no additional methods.
  WebAuthn.verifyWebauthnDevice({
    userChallenge: document.getElementById('user_challenge').value,
    credentialIds: document.getElementById('credential_ids').value,
  })
    .then((result) => {
      document.getElementById('credential_id').value = result.credentialId;
      document.getElementById('authenticator_data').value = result.authenticatorData;
      document.getElementById('client_data_json').value = result.clientDataJSON;
      document.getElementById('signature').value = result.signature;
      webauthnInProgressContainer.classList.add('hidden');
      webauthnSuccessContainer.classList.remove('hidden');
    })
    .catch((error) => {
      document.getElementById('errors').value = error;
      document.getElementById('platform').value = webauthnPlatformRequested;
      document.getElementById('webauthn_form').submit();
    });
}

function webauthnButton() {
  const button = document.getElementById('webauthn-button');
  button.addEventListener('click', webauthn);
}

document.addEventListener('DOMContentLoaded', webauthnButton);
