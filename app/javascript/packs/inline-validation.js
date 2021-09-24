// Allows inline validation with consistent errors across all browsers
function inlineValidation() {
    const alert = document.querySelector('.invalid-alert');
    const alertInput = document.querySelector('input');
    let blurTimer;
  
    // remove focus from the email input after error is displayed
    function blurInput(input) {
      blurTimer = setTimeout(function () {
        input.blur();
      }, 0);
    }

  
    function resetInvalid(input) {
      input.classList.remove('usa-input--error');
      alert.classList.add('display-none');
      alertInline.classList.add('display-none');
      clearTimeout(blurTimer);
    }
  
    function displayInvalid(input) {

      input.classList.add('usa-input--error');
      const alertInline = `
        <span class='usa-error-message--with-icon usa-error-message margin-top-1 margin-bottom-1' role='alert'>
          ${I18n.t('forms.ssn.show')}
        </span>`;
      input.insertAdjacentHTML('afterend', alert);
      blurInput(input);
    }
  
    if (alertInput) {
      alertInput.classList.add('usa-input'); // use usds 2.0 styles
      alertInput.addEventListener('invalid', (e) => {
        resetInvalid(e.target);
        if (!e.target.validity.valid) {
          displayInvalid(e.target);
        }
      });
      alertInput.addEventListener('input', (e) => {
        resetEmailInvalid(e.target);
      });
    }
  }
  
  document.addEventListener('DOMContentLoaded', inlineValidation);
  