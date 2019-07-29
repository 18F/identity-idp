function toggleButton() {
  const continueButton = document.querySelector('input[value="Continue"]');
  var checkbox = document.querySelector('input[name="ial2_consent_given"]');

  continueButton.disabled = true;

  checkbox.addEventListener("click", function() {
    continueButton.disabled = !continueButton.disabled;
  });
}

document.addEventListener('DOMContentLoaded', toggleButton);
