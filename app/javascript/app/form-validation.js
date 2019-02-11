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
            if (buttons.length !== 0 && input.checkValidity()) {
              [].forEach.call(buttons, function(button) {
                if (button.disabled && !button.classList.contains('no-auto-enable')) {
                  button.disabled = false;
                }
              });
            }
          });
        });
      }

      const conditional_required_inputs = form.querySelectorAll('input[data-required-if-checked]');

      if(conditional_required_inputs.length !== 0) {
        [].forEach.call(conditional_required_inputs, function(drivenInput) {
          const selector = drivenInput.getAttribute('data-required-if-checked');
          const drivingElement = form.querySelector(selector);

          if(drivingElement) {
            const otherInputs = form.querySelectorAll('input[name="' + drivingElement.name + '"]');
            const handler = function() {
              drivenInput.required = this == drivingElement;
              return true;
            }
            if(otherInputs.count !== 0) {
              [].forEach.call(otherInputs, function(input) {
                input.addEventListener('click', handler);
              });
            }
            drivenInput.addEventListener('focus', function() {
              drivingElement.click();
              return true;
            });
          }
        });
      }

      const conditional_visible_inputs = form.querySelectorAll('input[data-visible-if-checked]');

      if(conditional_visible_inputs.length !== 0) {
        [].forEach.call(conditional_visible_inputs, function(drivenInput) {
          const selector = drivenInput.getAttribute('data-visible-if-checked');
          const drivingElement = form.querySelector(selector);

          if(drivingElement) {
            const otherInputs = form.querySelectorAll('input[name="' + drivingElement.name + '"]');
            const handler = function() {
              var visible;
              visible = this == drivingElement;
              if(drivenInput.classList) {
                drivenInput.classList.toggle("hidden", !visible);
              }
              else if(visible) {
                drivenInput.className = drivenInput.className.replace(/\bhidden\b/g, "");
              }
              else {
                drivenInput.className = drivenInput.className + " hidden";
              }

              drivenInput.required = this == drivingElement;
              return true;
            }
            if(otherInputs.count !== 0) {
              [].forEach.call(otherInputs, function(input) {
                input.addEventListener('click', handler);
              });
            }
          }
        });
      }

      const inputs = form.querySelectorAll('.field');

      if (inputs.length !== 0) {
        [].forEach.call(inputs, function(input) {
          const types = ['dob', 'personal-key', 'ssn', 'state_id_number', 'zipcode'];

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
