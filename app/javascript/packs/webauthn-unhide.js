import { isWebAuthnEnabled } from '../app/webauthn';

export async function unhideWebauthn() {
  Object.entries({
    select_webauthn: isWebAuthnEnabled(),
    select_webauthn_platform:
    window.PublicKeyCredential &&
    PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable &&
    PublicKeyCredential.isConditionalMediationAvailable &&
      await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable() &&
      await PublicKeyCredential.isConditionalMediationAvailable(),
  }).forEach(([id, hasSupport]) => {
    const element = document.getElementById(id);
    element?.classList.toggle('display-none', !hasSupport);
  });

  /** @type {NodeListOf<HTMLInputElement>} */
  const checkboxes = document.querySelectorAll('input[name="two_factor_options_form[selection]"]');
  for (let i = 0, len = checkboxes.length; i < len; i += 1) {
    const checkbox = checkboxes[i];
    if (!checkbox.checked || !checkbox.closest('.display-none') || i + 1 >= len) {
      break;
    }

    checkboxes[i + 1].checked = true;
  }
}

if (process.env.NODE_ENV !== 'test') {
  unhideWebauthn();
}
