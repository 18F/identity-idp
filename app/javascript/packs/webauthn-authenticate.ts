import { isWebauthnSupported, verifyWebauthnDevice } from '@18f/identity-webauthn';
import type { VerifyCredentialDescriptor } from '@18f/identity-webauthn';

function webauthn() {
  const webauthnInProgressContainer = document.getElementById('webauthn-auth-in-progress')!;

  const spinner = document.getElementById('spinner')!;
  spinner.classList.remove('display-none');

  const credentials: VerifyCredentialDescriptor[] = JSON.parse(
    (document.getElementById('credentials') as HTMLInputElement).value,
  );

  if (!isWebauthnSupported()) {
    const href = webauthnInProgressContainer.getAttribute('data-webauthn-not-enabled-url')!;
    window.location.href = href;
  } else {
    // if platform auth is not supported on device, we should take user to the error screen if theres no additional methods.
    verifyWebauthnDevice({
      userChallenge: (document.getElementById('user_challenge') as HTMLInputElement).value,
      credentials,
    })
      .then((result) => {
        (document.getElementById('credential_id') as HTMLInputElement).value = result.credentialId;
        (document.getElementById('authenticator_data') as HTMLInputElement).value =
          result.authenticatorData;
        (document.getElementById('client_data_json') as HTMLInputElement).value =
          result.clientDataJSON;
        (document.getElementById('signature') as HTMLInputElement).value = result.signature;
      })
      .catch((error: Error) => {
        (document.getElementById('webauthn_error') as HTMLInputElement).value = error.name;
      })
      .then(() => {
        (document.getElementById('webauthn_form') as HTMLFormElement).submit();
      });
  }
}

function webauthnButton() {
  const button = document.getElementById('webauthn-button') as HTMLButtonElement;
  button.type = 'button';
  button.addEventListener('click', webauthn);
}

document.addEventListener('DOMContentLoaded', webauthnButton);
