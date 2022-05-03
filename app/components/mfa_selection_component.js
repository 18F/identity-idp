function clearPhoneSelectionError() {
  const error = document.getElementById('phone_error');
  const invalid = document.querySelector('label.checkbox__invalid');
  if (error) {
    error.style.display = 'none';
  }
  if (invalid) {
    invalid.classList.remove('checkbox__invalid');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const checkboxes = document.getElementsByName('two_factor_options_form[selection][]');
  checkboxes.forEach((checkbox) => {
    checkbox.onchange = clearPhoneSelectionError;
  });
});

document
  .getElementsByClassName('usa-checkbox__label-description')[4]
  .appendChild(document.createTextNode('<YOUR_CONTENT>'));
