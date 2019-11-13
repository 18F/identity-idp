// Allows HTML5 email validation with consistent errors across all browsers
function emailValidation() {
  const alert = document.querySelector('.email-invalid-alert');
  const alertInline = document.querySelector('.email-invalid-alert-inline');
  const email = document.querySelector('input[type="email"]');
  var blurTimer;

  if (email) {
    email.classList.remove('field');
    email.classList.add('usa-input'); // use usds 2.0 styles
    email.addEventListener('invalid', (e) => {
      resetEmailInvalid(e.target);
      if (!e.target.validity.valid) {
        displayEmailInvalid(e.target);
      }
    });
    email.addEventListener('input', (e) => {
      resetEmailInvalid(e.target);
    });
  }

  function resetEmailInvalid(input){
    input.classList.remove('usa-input--error');
    alert.classList.add('hide');
    alertInline.classList.add('hide');
    clearTimeout(blurTimer);
  }

  function displayEmailInvalid(input){
    input.classList.add('usa-input--error');
    alert.classList.remove('hide');
    alertInline.classList.remove('hide');
    blurEmailInput(input);
  }

  // remove focus from the email input after error is displayed
  function blurEmailInput(input){
    blurTimer = setTimeout(function () {
      input.blur();
    }, 0);
  }
}

document.addEventListener('DOMContentLoaded', emailValidation);
