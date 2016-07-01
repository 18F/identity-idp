import $ from 'jquery';


// Removing element from DOM (on click containing appropriate data attribute)
const dismiss = '[data-dismiss="true"]';
$(document).on('click', dismiss, (e) => { $(e.target).parent().remove(); });


// Safari & IE 8/9 do not support client side validation of form inputs; this adds basic messaging
// and styling fallback for these browsers. "page:load" event needed because of turbolinks, which
// overrides normal loading process
$(document).on('ready page:load', () => {
  // Detect if HTML5 form validation is available
  const hasHtml5Validation = typeof document.createElement('input').checkValidity === 'function';
  const ua = navigator.userAgent;
  const isSafari = ua.indexOf('Safari') !== -1 && ua.indexOf('Chrome') === -1;
  // If HTML5 form validation is not supported, or Safari is being used:
  if (!hasHtml5Validation || isSafari) {
    $('form').on('submit', function(e) {
      if (!this.checkValidity()) {
        const $form = $(this);
        const $required = $form.find('[required]').filter(function() { return this.value === ''; });
        const $pattern = $form.find('[pattern]').filter(function() { return this.value; });
        const message = '<div class="error-notify alert-danger p1 mt1 mb2">' +
          'Please fill in all required fields using the requested format.</div>';

        // Clean up any old error messages
        $('input').removeClass('border-red');
        $('.error-notify').remove();

        // Highlight any required fields without a value
        if ($required.length) {
          e.preventDefault();
          $required.addClass('border-red');
        }

        // Highlight any fields that do not match requested pattern
        let hasValidPattern = true;
        if ($pattern.length) {
          $pattern.each(function() {
            const $patternField = $(this);
            const $patternValue = $patternField.prop('pattern');
            const $regex = new RegExp(`^${$patternValue}$`);
            if (!$patternField.val().match($regex)) {
              e.preventDefault();
              $patternField.addClass('border-red');
              hasValidPattern = false;
            }
          });
        }

        // Display error message
        if ($required.length || !hasValidPattern) {
          $form.prepend(message);
        }
      }
    });
  }
});
