import $ from 'jquery';


function ready() {
  const checkboxSelector = '#user_second_factor_ids_mobile';
  const $checkbox = $(checkboxSelector);
  const $input = $('#user_mobile');
  const $inputCntnr = $('.toggle-mobile');

  function loginCheckMobileField() {
    if ($checkbox.is(':checked')) {
      $inputCntnr.show();
      $input.attr('required', 'required').addClass('required');
    } else {
      $inputCntnr.hide();
      $input.removeAttr('required').removeClass('required');
    }
  }

  $(document).on('click', checkboxSelector, loginCheckMobileField);
}


$(document).on('ready page:load', ready);
