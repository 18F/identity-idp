$(document).on('page:change', function () {
  $('#user_mobile').on('keyup', function (){
    if(this.value !== ''){
      $('#user_second_factor_ids_mobile').prop('checked', 'checked');
    }
    else{
      $('#user_second_factor_ids_mobile').prop('checked', '');
      $('#user_mobile').removeAttr('required');
      $('#user_mobile').removeClass('required');
    }
  });
});
