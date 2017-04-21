const I18n = window.LoginGov.I18n;

document.addEventListener('DOMContentLoaded', () => {
  const form = document.querySelector('form');
  if (form) {
    const fields = ['dob', 'ssn', 'zipcode'];

    fields.forEach(function(fieldType) {
      const input = document.querySelector(`.${fieldType}`);

      if (input) {
        input.addEventListener('change', () => {
          if (input.validity.patternMismatch) {
            input.setCustomValidity(I18n.t(`idv.errors.pattern_mismatch.${fieldType}`));
          } else {
            input.setCustomValidity('');
          }
        });
      }
    });
  }
});
