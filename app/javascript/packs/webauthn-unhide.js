import { loadPolyfills } from '@18f/identity-polyfill';
import { isWebAuthnEnabled } from '../app/webauthn';

async function unhideWebauthn() {
  Object.entries({
    select_webauthn: isWebAuthnEnabled(),
    select_webauthn_platform: await PublicKeyCredential?.isUserVerifyingPlatformAuthenticatorAvailable(),
  }).forEach(([id, hasSupport]) => {
    const element = document.getElementById(id);
    element?.classList.toggle('display-none', !hasSupport);
  });

  /** @type {NodeListOf<HTMLInputElement>} */
  const checkboxes = document.querySelectorAll('input[name="two_factor_options_form[selection]"]');
  for (let i = 0, len = checkboxes.length; i < len; i += 1) {
    const checkbox = checkboxes[i];
    if (!checkbox.checked || !checkbox.classList.contains('display-none') || i + 1 >= len) {
      break;
    }

    checkboxes[i + 1].checked = true;
  }
}

loadPolyfills(['classlist']).then(unhideWebauthn);
