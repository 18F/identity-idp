const I18n = window.LoginGov.I18n;

document.addEventListener('DOMContentLoaded', () => {
  const form = document.querySelector('form');
  if (form && window.onbeforeunload) {
    form.addEventListener('submit', () => {
      if (form.checkValidity()) window.onbeforeunload = false;
    });

    const fields = ['dob', 'ssn', 'zipcode'];

    fields.forEach(function(f) {
      const input = document.querySelector(`.${f}`);
      if (input) {
        input.addEventListener('input', () => {
          if (input.validity.patternMismatch) {
            input.setCustomValidity(I18n.t(`idv.errors.pattern_mismatch.${f}`));
          } else {
            input.setCustomValidity('');
          }
        });
      }
    });
  }
});
