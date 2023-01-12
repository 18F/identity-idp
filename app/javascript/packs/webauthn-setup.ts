import { isWebAuthnEnabled, enrollWebauthnDevice } from '../app/webauthn';

/**
 * Reloads the current page, presenting the message corresponding to the given error key.
 *
 * @param error Error key for which to show message.
 * @param options Optional options.
 * @param options.force If true, reload the page even if that error is already shown.
 */
export function reloadWithError(error: string, { force = false }: { force?: boolean } = {}) {
  const params = new URLSearchParams(window.location.search);
  if (force || params.get('error') !== error) {
    params.set('error', error);
    window.location.search = params.toString();
  }
}

function webauthn() {
  if (!isWebAuthnEnabled()) {
    reloadWithError('NotSupportedError');
  }
  const continueButton = document.getElementById('continue-button')!;
  continueButton.addEventListener('click', () => {
    document.getElementById('spinner')!.classList.remove('display-none');
    document.getElementById('continue-button')!.className = 'display-none';

    const platformAuthenticator =
      (document.getElementById('platform_authenticator') as HTMLInputElement).value === 'true';

    enrollWebauthnDevice({
      userId: (document.getElementById('user_id') as HTMLInputElement).value,
      userEmail: (document.getElementById('user_email') as HTMLInputElement).value,
      userChallenge: (document.getElementById('user_challenge') as HTMLInputElement).value,
      excludeCredentials: (document.getElementById('exclude_credentials') as HTMLInputElement)
        .value,
      platformAuthenticator,
    })
      .then((result) => {
        (document.getElementById('webauthn_id') as HTMLInputElement).value = result.webauthnId;
        (document.getElementById('webauthn_public_key') as HTMLInputElement).value =
          result.webauthnPublicKey;
        (document.getElementById('attestation_object') as HTMLInputElement).value =
          result.attestationObject;
        (document.getElementById('client_data_json') as HTMLInputElement).value =
          result.clientDataJSON;
        (document.getElementById('webauthn_form') as HTMLFormElement).submit();
      })
      .catch((err) => reloadWithError(err.name, { force: true }));
  });
  const input = document.getElementById('nickname') as HTMLInputElement;
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

if (process.env.NODE_ENV !== 'test') {
  webauthn();
}
