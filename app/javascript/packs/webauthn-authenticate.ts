import { isWebauthnSupported, verifyWebauthnDevice } from '@18f/identity-webauthn';

function webauthn() {
  const webauthnInProgressContainer = document.getElementById('webauthn-auth-in-progress')!;
  const webauthnSuccessContainer = document.getElementById('webauthn-auth-successful')!;

  const webauthnPlatformRequested =
    webauthnInProgressContainer.dataset.platformAuthenticatorRequested === 'true';
  const multipleFactorsEnabled =
    webauthnInProgressContainer.dataset.multipleFactorsEnabled === 'true';
  const isPlatformAvailable =
    (document.getElementById('webauthn_device') as HTMLInputElement).value === 'true';

  const spinner = document.getElementById('spinner')!;
  spinner.classList.remove('display-none');

  if (
    !isWebauthnSupported() ||
    (webauthnPlatformRequested && !isPlatformAvailable && !multipleFactorsEnabled)
  ) {
    const href = webauthnInProgressContainer.getAttribute('data-webauthn-not-enabled-url')!;
    window.location.href = href;
  } else {
    // if platform auth is not supported on device, we should take user to the error screen if theres no additional methods.
    verifyWebauthnDevice({
      userChallenge: (document.getElementById('user_challenge') as HTMLInputElement).value,
      credentialIds: (document.getElementById('credential_ids') as HTMLInputElement).value,
    })
      .then((result) => {
        (document.getElementById('credential_id') as HTMLInputElement).value = result.credentialId;
        (document.getElementById('authenticator_data') as HTMLInputElement).value =
          result.authenticatorData;
        (document.getElementById('client_data_json') as HTMLInputElement).value =
          result.clientDataJSON;
        (document.getElementById('signature') as HTMLInputElement).value = result.signature;
        webauthnInProgressContainer.classList.add('display-none');
        webauthnSuccessContainer.classList.remove('display-none');
      })
      .catch((error: Error) => {
        (document.getElementById('webauthn_error') as HTMLInputElement).value = error.name;
        (document.getElementById('platform') as HTMLInputElement).value =
          String(webauthnPlatformRequested);
        (document.getElementById('webauthn_form') as HTMLFormElement).submit();
      });
  }
}

function webauthnButton() {
  const button = document.getElementById('webauthn-button')!;
  button.addEventListener('click', webauthn);
}

function isPlatformAuthenticatorAvailable() {
  return window.PublicKeyCredential?.isUserVerifyingPlatformAuthenticatorAvailable().then(
    (result) => {
      (document.getElementById('webauthn_device') as HTMLInputElement).value = String(result);
    },
  );
}

document.addEventListener('DOMContentLoaded', webauthnButton);
document.addEventListener('DOMContentLoaded', isPlatformAuthenticatorAvailable);
