import 'classlist.js';

function clearRadioBtn(name) {
  const radioGroup = document.querySelectorAll(`input[name='${name}']`);

  for (let i = 0; i < radioGroup.length; i++) {
    radioGroup[i].parentNode.parentNode.classList.remove('bg-light-blue');
  }
}

function radioBtn() {
  const radios = document.querySelectorAll('.radio-btn input[type=radio]');

  if (radios) {
    for (let i = 0; i < radios.length; i++) {
      let radio = radios[i];
      const label = radio.parentNode.parentNode;
      const name = radio.getAttribute('name');

      if (radio.checked) label.classList.add('bg-light-blue');

      radio.addEventListener('change', function() {
        clearRadioBtn(name);
        if (radio.checked) label.classList.add('bg-light-blue');
      });

      radio.addEventListener('focus', function() {
        label.classList.add('is-focused');
      });

      radio.addEventListener('blur', function() {
        label.classList.remove('is-focused');
      });
    }
  }
}


document.addEventListener('DOMContentLoaded', radioBtn);
