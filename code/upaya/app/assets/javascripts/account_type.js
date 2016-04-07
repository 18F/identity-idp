$(document).on('page:change', function () {
  $('span.radio').click(function () {
    $(this).children('input').each(function () {
      $(this).prop('checked', true);
    });
    return true;
  });

  $('label.radio_buttons').wrap('<legend></legend>');
  $('.form-group.user_account_type').wrap('<fieldset></fieldset>');
});
