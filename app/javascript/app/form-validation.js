import 'classlist.js';

const I18n = window.LoginGov.I18n;

document.addEventListener('DOMContentLoaded', () => {
  const forms = document.querySelectorAll('form');

  function addListenerMulti(el, events, fn) {
    events.split(' ').forEach(e => el.addEventListener(e, fn, false));
  }

  if (forms.length !== 0) {
    [].forEach.call(forms, function(form) {
      const buttons = form.querySelectorAll('[type="submit"]');
      form.addEventListener('submit', function() {
        if (buttons.length !== 0) {
          [].forEach.call(buttons, function (button) {
            button.disabled = true;
          });
        }
      }, false);
      const elements = form.querySelectorAll('input');
      if (elements.length !== 0) {
        [].forEach.call(elements, function(input) {
          input.addEventListener('input', function () {
            if (buttons.length !== 0) {
              [].forEach.call(buttons, function(button) {
                if (button.disabled) {
                  button.disabled = false;
                }
              });
            }
          });
        });
      }

      const inputs = form.querySelectorAll('.field');

      if (inputs.length !== 0) {
        [].forEach.call(inputs, function(input) {
          const types = ['dob', 'personal-key', 'ssn', 'zipcode'];

          addListenerMulti(input, 'input invalid', (e) => {
            e.target.setCustomValidity('');

            if (e.target.validity.valueMissing) {
              e.target.setCustomValidity(I18n.t('simple_form.required.text'));
            } else if (e.target.validity.patternMismatch) {
              types.forEach(function(type) {
                if (e.target.classList.contains(type)) {
                  e.target.setCustomValidity(I18n.t(`idv.errors.pattern_mismatch.${I18n.key(type)}`));
                }
              });
            }
          });
        });
      }
    });
  }
});
