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
      const errorClasses = 'mt-tiny h6 red error-message';
      let errorDiv;
      if (sibling && sibling.classlist.contains(errorClasses) === true) {
        errorDiv = sibling;
      } else {
        errorDiv = document.createElement('div');
        errorDiv.setAttribute('class', errorClasses);
        input.parentNode.appendChild(errorDiv);
      }

      input.addEventListener('change', function() {
        if (this.dataset.supportedJurisdictions.indexOf(input.value) === -1) {
          errorDiv.innerHTML = [this.dataset.errorMessage, this.dataset.errorMessageSp].join(' ');
        } else {
          errorDiv.innerHTML = '';
        }
      });
    });
  }
}

document.addEventListener('DOMContentLoaded', validateStateSelection);
