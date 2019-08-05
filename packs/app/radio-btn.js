import 'classlist.js';

function clearHighlight(name) {
  const radioGroup = document.querySelectorAll(`input[name='${name}']`);

  Array.prototype.forEach.call(radioGroup, (radio) => {
    radio.parentNode.parentNode.classList.remove('bg-lightest-blue');
  });
}

function highlightRadioBtn() {
  const radios = document.querySelectorAll('.btn-border input[type=radio]');

  if (radios) {
    Array.prototype.forEach.call(radios, (radio) => {
      const label = radio.parentNode.parentNode;
      const name = radio.getAttribute('name');

      if (radio.checked) label.classList.add('bg-lightest-blue');

      radio.addEventListener('change', function() {
        clearHighlight(name);
        if (radio.checked) label.classList.add('bg-lightest-blue');
      });

      radio.addEventListener('focus', function() {
        const autofocusedInput = label.querySelector('input.auto-focus');
        label.classList.add('is-focused');
        if (autofocusedInput) { autofocusedInput.focus(); }
      });

      radio.addEventListener('blur', function() {
        label.classList.remove('is-focused');
      });
    });
  }
}


document.addEventListener('DOMContentLoaded', highlightRadioBtn);
