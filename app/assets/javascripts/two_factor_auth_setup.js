function loginCheckMobileField () {
  if ($('#user_second_factor_ids_mobile').is(':checked')) {
    $('.toggle-mobile').show();
    $('#user_mobile').attr('required', 'required');
    $('#user_mobile').addClass('required');
  } else {
    $('.toggle-mobile').hide();
    $('#user_mobile').removeAttr('required');
    $('#user_mobile').removeClass('required');
  }
}

$(document).on('page:change', function () {
  $('#user_second_factor_ids_mobile').change(function () {
    loginCheckMobileField();
  });
});
