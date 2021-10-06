function toggleButton() {
  const continueButton = document.querySelector('button[type="submit"]');
  const checkbox = document.querySelector('input[name="ial2_consent_given"]');
  const errorMessage = document.querySelector('.js-consent-form-alert');

  function sync() {
    continueButton.classList.toggle('usa-button--disabled', !checkbox.checked);
    errorMessage.classList.toggle(
      'display-none',
      checkbox.getAttribute('aria-invalid') !== 'value-missing',
    );
  }

  sync();
  checkbox.addEventListener('change', sync);
  checkbox.addEventListener('invalid', sync);
}

document.addEventListener('DOMContentLoaded', toggleButton);
