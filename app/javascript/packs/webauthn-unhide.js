function unhideWebauthn() {
  if (navigator && navigator.credentials && navigator.credentials.create) {
    const elem = document.getElementById('select_webauthn');
    if (elem) {
      elem.classList.remove('hidden');
    }
  } else {
    const checkboxes = document.querySelectorAll('input[name="two_factor_options_form[selection]"]');
    for (let i = 0, len = checkboxes.length; i < len; i += 1) {
      if (!checkboxes[i].classList.contains('hidden')) {
        checkboxes[i].checked = true;
        break;
      }
    }
  }
}
document.addEventListener('DOMContentLoaded', unhideWebauthn);
