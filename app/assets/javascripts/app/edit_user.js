import $ from 'jquery';


function ready() {
  const $input = $('#user_mobile');
  const $checkbox = $('#user_second_factor_ids_mobile');

  $input.on('keyup', () => {
    if (this.value !== '') {
      $checkbox.prop('checked', 'checked');
    } else {
      $checkbox.prop('checked', '');
      $input.removeAttr('required').removeClass('required');
    }
  });
}


$(document).on('page:change', ready);
