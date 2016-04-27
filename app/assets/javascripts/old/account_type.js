$(document).on('page:change', function () {
  $('span.radio').click(function () {
    $(this).children('input').each(function () {
      $(this).prop('checked', true);
    });
    return true;
  });
});
