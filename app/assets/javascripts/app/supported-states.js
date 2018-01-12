function validateStateSelection() {
  /********************************************************
  * Checks current option in select field against a space-separated string
  * of options passed in via a `data-supported-jurisdictions` attribute.
  * If the selected value is not in the string, it appends an error message, 
  * which is passed in via a data-error-message attribute.
  * 
  * The check happens onchange. If the value is acceptable, any existing 
  * error message is removed.
  **********************************************************/
  const state_fields = document.querySelectorAll('[data-supported-jurisdictions]');

  if (state_fields) {
    [].slice.call(state_fields).forEach((input, i) => {
      const errorDiv = '<div class="mt-tiny h6 red error-message"></div>'
      input.insertAdjacentHTML('afterend', errorDiv);
      
      input.addEventListener('change', function() {
        if (this.dataset.supportedJurisdictions.indexOf(input.value) == -1) {
          this.nextElementSibling.innerHTML = this.dataset.errorMessage;
        } else {
          this.nextElementSibling.innerHTML = '';
        }
      });
    });
  };
}

document.addEventListener('DOMContentLoaded', validateStateSelection);
