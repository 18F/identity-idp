import $ from 'jquery';


// Removing element from DOM (on click containing appropriate data attribute)
const dismiss = '[data-dismiss="true"]';
$(document).on('click', dismiss, (e) => { $(e.target).parent().remove(); });


// Safari & IE 8/9 do not support client side handling of `required` attribute on
// form inputs; this adds basic messaging and styling fallback for these browsers
$(document).on('ready', () => {
  const message = '<div class="bold mb2">Please fill in all required fields.</div>';

  $('form').on('submit', function(e) {
    const $form = $(this);
    const $fields = $form.find('[required]').filter(function() { return this.value === ''; });

    if ($fields.length) {
      e.preventDefault();
      $form.prepend(message);
      $fields.each(function() { $(this).addClass('border-red'); });
    }
  });
});
