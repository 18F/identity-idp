function validateStateSelection() {
  /* *******************************************************
  * Checks current option in select field against a space-separated string
  * of options passed in via a `data-supported-jurisdictions` attribute.
  *
  * If the selected value is not in the string, it appends an error message,
  * which is passed in via a data-error-message attribute.
  *
  * The check happens onchange. If the value is acceptable, any existing
  * error message is removed.
  ********************************************************* */
  const stateFields = document.querySelectorAll('[data-supported-jurisdictions]');

  if (stateFields) {
    [].slice.call(stateFields).forEach((input) => {
      // Check if an error div is already present. If so, use it.
      const sibling = input.nextElementSibling;
      if (sibling && sibling.classlist.contains('error-message') === true) {
        const errorDiv = sibling;
      } else {
        const errorDiv = '<div class="mt-tiny h6 red error-message"></div>';
        input.insertAdjacentHTML('afterend', errorDiv);
      }

      input.addEventListener('change', function() {
        if (this.dataset.supportedJurisdictions.indexOf(input.value) === -1) {
          this.nextElementSibling.innerHTML = [this.dataset.errorMessage, this.dataset.errorMessageSp].join(' ');
        } else {
          this.nextElementSibling.innerHTML = '';
        }
      });
    });
  }
}

document.addEventListener('DOMContentLoaded', validateStateSelection);
