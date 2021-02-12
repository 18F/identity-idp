function toggleButton() {
  const continueButton = document.querySelector('button[type="submit"]');
  const checkbox = document.querySelector('input[name="ial2_consent_given"]');

  function sync() {
    continueButton.classList.toggle('btn-disabled');
  }

  sync();
  checkbox.addEventListener('change', sync);
}

document.addEventListener('DOMContentLoaded', toggleButton);
