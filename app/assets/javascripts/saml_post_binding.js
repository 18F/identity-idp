document.addEventListener('DOMContentLoaded', function() {
  var samlForm = document.getElementById('saml-post-binding');
  if (samlForm) {
    document.body.className += ' hidden';
    samlForm.submit();
  }
});
