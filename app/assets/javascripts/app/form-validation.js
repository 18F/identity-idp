const I18n = window.LoginGov.I18n;

document.addEventListener('DOMContentLoaded', () => {
  const form = document.querySelector('form');
  if (form) {
    const fields = ['dob', 'personal-key', 'ssn', 'zipcode'];

    fields.forEach(function(f) {
      const input = document.querySelector(`.${f}`);
      if (input) {
        input.addEventListener('input', () => {
          if (input.validity.patternMismatch) {
            input.setCustomValidity(I18n.t(`idv.errors.pattern_mismatch.${I18n.key(f)}`));
          } else {
            input.setCustomValidity('');
          }
        });
      }
    });
  }
});
