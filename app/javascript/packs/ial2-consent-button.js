function toggleButton() {
  const continueButton = document.querySelector('input[value="Continue"]');
  const checkbox = document.querySelector('input[name="ial2_consent_given"]');

  console.log(checkbox);

  if (checkbox.checked == true) {
    console.log("HEY")
  }

  console.log(continueButton);
}

document.addEventListener('DOMContentLoaded', toggleButton);
