import 'classlist.js';

document.addEventListener('DOMContentLoaded', () => {
  function hideAll(elems) {
    Array.prototype.forEach.call(elems, (el) => {
      el.classList.add('hide');
    });
  }

  function showInput(radio) {
    const inputWrappers = document.querySelectorAll('.js-finance-wrapper');
    hideAll(inputWrappers);

    const financeType = radio.value;
    const inputWrapperToShow = document.querySelector(`[data-type="${financeType}"]`);
    inputWrapperToShow.classList.remove('hide');
  }

  const financeCntnr = document.querySelector('.js-finance-choice-cntnr');

  if (financeCntnr) {
    const inputWrappers = document.querySelectorAll('.js-finance-wrapper');
    hideAll(inputWrappers);

    const currentRadio = financeCntnr.querySelector('input[type="radio"][checked]');
    const radios = financeCntnr.querySelectorAll('input[type="radio"]');

    showInput(currentRadio || radios[0]);

    Array.prototype.forEach.call(radios, (el) => {
      el.addEventListener('change', () => {
        if (el.checked) {
          showInput(el);
        }
      });
    });
  }
});
