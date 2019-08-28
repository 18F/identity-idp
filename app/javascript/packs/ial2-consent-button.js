function toggleButton() {
  const continueButton = document.querySelector('input[value="Continue"]');
  const checkbox = document.querySelector('input[name="ial2_consent_given"]');

  continueButton.disabled = true;
  continueButton.classList.add('btn-disabled');

  checkbox.addEventListener('click', function() {
    if (continueButton.disabled) {
      continueButton.classList.remove('btn-disabled');
    } else {
      continueButton.classList.add('btn-disabled');
    }
    continueButton.disabled = !continueButton.disabled;
  });
}

document.addEventListener('DOMContentLoaded', toggleButton);
