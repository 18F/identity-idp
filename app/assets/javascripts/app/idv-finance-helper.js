import 'classlist.js';

document.addEventListener('DOMContentLoaded', () => {
  function hideAll(elems) {
    Array.prototype.forEach.call(elems, (el) => {
      el.classList.add('hide');
    });
  }

  function showInput(name) {
    const inputWrappers = document.querySelectorAll('.js-finance-wrapper');
    hideAll(inputWrappers);

    const inputWrapperToShow = document.querySelector(`[data-type="${name}"]`);
    if (inputWrapperToShow) {
      inputWrapperToShow.classList.remove('hide');
    }
  }

  const financeSelect = document.querySelector('.js-finance-choice-select');
  const submitButton = document.querySelector('.js-finance-submit');

  if (financeSelect) {
    const inputWrappers = document.querySelectorAll('.js-finance-wrapper');
    hideAll(inputWrappers);
    showInput('blank');

    financeSelect.addEventListener('change', () => {
      showInput(financeSelect.value || 'blank');
      submitButton.disabled = !financeSelect.value;
    });
  }
});
