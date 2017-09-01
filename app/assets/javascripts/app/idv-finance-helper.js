import 'classlist.js';

document.addEventListener('DOMContentLoaded', () => {
  function hideAll(elems) {
    Array.prototype.forEach.call(elems, (el) => {
      el.classList.add('hide');
    });
  }

  function removeError() {
    const errorMessage = document.querySelector('.error-message');

    if (errorMessage) {
      errorMessage.parentNode.classList.remove('has-error');
      errorMessage.parentNode.removeChild(errorMessage);
    }
  }

  function showInput(name) {
    const inputWrappers = document.querySelectorAll('.js-finance-wrapper');
    hideAll(inputWrappers);

    const inputWrapperToShow = document.querySelector(`[data-type="${name}"]`);
    if (inputWrapperToShow) {
      inputWrapperToShow.classList.remove('hide');
    }
  }

  const financeRadios = document.querySelectorAll('.js-finance-choice-select');
  const financeChecked = document.querySelector('.js-finance-choice-select:checked');
  const submitButton = document.querySelector('.js-finance-submit');

  if (financeRadios) {
    const inputWrappers = document.querySelectorAll('.js-finance-wrapper');
    hideAll(inputWrappers);

    if (financeChecked) {
      showInput(financeChecked.value || '');
    }

    Array.prototype.forEach.call(financeRadios, function (radio) {
      radio.addEventListener('change', (e) => {
        e = e || window.event;
        removeError();
        showInput(e.target.value || '');
        submitButton.disabled = false;
      });
    });

    submitButton.disabled = true;
  }
});
