import {
  isWebauthnSupported,
  enrollWebauthnDevice,
  extractCredentials,
  longToByteArray,
} from '@18f/identity-webauthn';
import { forceRedirect } from '@18f/identity-url';
import type { Navigate } from '@18f/identity-url';

/**
 * Reloads the current page, presenting the message corresponding to the given error key.
 *
 * @param error Error key for which to show message.
 * @param options Optional options.
 * @param options.force If true, reload the page even if that error is already shown.
 * @param options.initialURL Initial URL value.
 * @param options.navigate Navigate implementation.
 */
export function reloadWithError(
  error: string,
  {
    force = false,
    initialURL = window.location.href,
    navigate = forceRedirect,
  }: { force?: boolean; initialURL?: string; navigate?: Navigate } = {},
) {
  const url = new URL(initialURL);
  if (force || url.searchParams.get('error') !== error) {
    url.searchParams.set('error', error);
    navigate(url.toString());
  }
}

function webauthn() {
  if (!isWebauthnSupported()) {
    reloadWithError('NotSupportedError');
  }
  const form = document.getElementById('webauthn_form') as HTMLFormElement;
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    document.getElementById('spinner')!.classList.remove('display-none');
    document.getElementById('continue-button')!.className = 'display-none';

    const platformAuthenticator =
      (document.getElementById('platform_authenticator') as HTMLInputElement).value === 'true';

    enrollWebauthnDevice({
      user: {
        id: longToByteArray(Number((document.getElementById('user_id') as HTMLInputElement).value)),
        name: (document.getElementById('user_email') as HTMLInputElement).value,
        displayName: (document.getElementById('user_email') as HTMLInputElement).value,
      },
      challenge: new Uint8Array(
        JSON.parse((document.getElementById('user_challenge') as HTMLInputElement).value),
      ),
      excludeCredentials: extractCredentials(
        (document.getElementById('exclude_credentials') as HTMLInputElement).value
          .split(',')
          .filter(Boolean),
      ),
      authenticatorAttachment: platformAuthenticator ? 'platform' : 'cross-platform',
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
}

if (process.env.NODE_ENV !== 'test') {
  webauthn();
}
