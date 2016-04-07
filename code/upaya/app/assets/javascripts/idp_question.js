$(document).on('page:change', function () {
  if ($('input[type=radio]:checked').size() === 0) {
    $('#submit_answer').prop('disabled', true);
  }
  $('input:radio[name="answer"]').click(function() {
    $('#submit_answer').prop('disabled',false);
  });
});
