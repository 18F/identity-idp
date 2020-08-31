function toggleButton() {
  const continueButton = document.querySelector('input[value="Continue"]');
  const checkbox = document.querySelector('input[name="ial2_consent_given"]');

  function sync() {
    continueButton.disabled = !checkbox.checked;
    continueButton.classList.toggle('btn-disabled', continueButton.disabled);
  }

  sync();
  checkbox.addEventListener('change', sync);
}

document.addEventListener('DOMContentLoaded', toggleButton);
