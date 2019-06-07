const WebAuthn = require('../app/webauthn');

function unhideWebauthn() {
  if (WebAuthn.isWebAuthnEnabled()) {
    const elem = document.querySelector('label[for=two_factor_options_form_selection_webauthn]');
    if (elem) {
      elem.classList.remove('hide');
    }
  }
}
document.addEventListener('DOMContentLoaded', unhideWebauthn);
