function toggleButton() {
  const continueButton = document.querySelector('button[type="submit"]');
  const checkbox = document.getElementById('user_terms_accepted');

  function sync() {
    continueButton.classList.toggle('usa-button--disabled', !checkbox.checked);
  }

  sync();
  checkbox.addEventListener('change', sync);
}

document.addEventListener('DOMContentLoaded', toggleButton);
