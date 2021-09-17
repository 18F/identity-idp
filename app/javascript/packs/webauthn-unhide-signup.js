const WebAuthn = require('../app/webauthn');

function unhideWebauthn() {
  if (WebAuthn.isWebAuthnEnabled()) {
    const elem = document.getElementById('select_webauthn');
    if (elem) {
      elem.classList.remove('display-none');
    }
  }
}
document.addEventListener('DOMContentLoaded', unhideWebauthn);
