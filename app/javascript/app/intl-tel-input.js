function intlTelInput() {
  const flagContainer = document.querySelectorAll('.flag-container');
  if (flagContainer) {
    [].slice.call(flagContainer).forEach((element) => {
      element.setAttribute('aria-label', 'Country code');
    });
  }
  const selectedFlag = document.querySelectorAll('.flag-container .selected-flag');
  if (selectedFlag) {
    [].slice.call(selectedFlag).forEach((element) => {
      element.setAttribute('aria-haspopup', 'true');
      element.setAttribute('role', 'button');
    });
  }
  const country = document.querySelectorAll('.flag-container .country');
  if (country) {
    [].slice.call(country).forEach((element) => {
      element.setAttribute('tabindex', '-1');
    });
  }
}


document.addEventListener('DOMContentLoaded', intlTelInput);
