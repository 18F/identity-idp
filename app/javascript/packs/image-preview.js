import $ from 'jquery';

function imagePreview() {
  $('#take_picture').on('click', function() {
    document.getElementById('doc_auth_image').click();
  });
  $('#doc_auth_image').on('change', function(event) {
    $('.simple_form .alert-error').hide();
    $('.simple_form .alert-notice').hide();
    const files = event.target.files;
    const image = files[0];
    const reader = new FileReader();
    reader.onload = function(file) {
      const img = new Image();
      img.onload = function () {
        const displayWidth = '460';
        const ratio = (this.height / this.width);
        img.width = displayWidth;
        img.height = (displayWidth * ratio);
        $('#target').html(img);
      };
      img.src = file.target.result;
      $('#target').html(img);
    };
    reader.readAsDataURL(image);
  });
}

document.addEventListener('DOMContentLoaded', imagePreview);
