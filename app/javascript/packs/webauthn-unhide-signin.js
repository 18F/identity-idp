const WebAuthn = require('../app/webauthn');

function unhideWebauthn() {
  if (WebAuthn.isWebAuthnEnabled()) {
    const elem = document.getElementById('select_webauthn');
    if (elem) {
      elem.classList.remove('hide');
    }
  } else {
    const checkboxes = document.querySelectorAll('input[name="two_factor_options_form[selection]"]');
    for (let i = 0, len = checkboxes.length; i < len; i += 1) {
      if (!checkboxes[i].classList.contains('hide')) {
        checkboxes[i].checked = true;
        break;
      }
    }
  }
}
document.addEventListener('DOMContentLoaded', unhideWebauthn);
