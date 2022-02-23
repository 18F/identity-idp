const { I18n } = window.LoginGov;
const WebAuthn = require('../app/webauthn');

function webauthn() {
  // If webauthn is not supported redirect back to the 2fa options list
  const webauthnInProgressContainer = document.getElementById('webauthn-auth-in-progress');
  const webauthnSuccessContainer = document.getElementById('webauthn-auth-successful');

  const webauthnPlatformRequested =
    webauthnInProgressContainer.getAttribute('data-platform-authenticator-requested') === 'true';
  const multipleFactorsEnabled =
    webauthnInProgressContainer.getAttribute('data-multiple-factors-enabled') === 'true';
  const webauthnPlatformEnabled = await window.PublicKeyCredential?.isUserVerifyingPlatformAuthenticatorAvailable();

  if (!WebAuthn.isWebAuthnEnabled()) {
    const href = webauthnInProgressContainer.getAttribute('data-webauthn-not-enabled-url');
    window.location.href = href;
  }

  const spinner = document.getElementById('spinner');
  spinner.classList.remove('hidden');

  // if platform auth is not supported on device, we should take user to the error screen if theres no additional methods.
  if (webauthnPlatformRequested && !webauthnPlatformEnabled && !multipleFactorsEnabled) {
    document.getElementById('errors').value = I18n.t('');
    document.getElementById('platform').value = true;
    document.getElementById('webauthn_form').submit();
  } else {
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
}

function webauthnButton() {
  const button = document.getElementById('webauthn-button');
  button.addEventListener('click', webauthn);
}

document.addEventListener('DOMContentLoaded', webauthnButton);
