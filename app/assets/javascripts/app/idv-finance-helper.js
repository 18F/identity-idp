document.addEventListener('DOMContentLoaded', () => {
  const financeCntnr = document.querySelector('.js-finance-choice-cntnr');

  if (financeCntnr) {
    const radios = financeCntnr.querySelectorAll('input[type="radio"]');
    const label = document.querySelector('.js-finance-label');

    Array.prototype.forEach.call(radios, (el) => {
      el.addEventListener('change', () => {
        label.textContent = el.parentElement.textContent;
      });
    });
  }
});
