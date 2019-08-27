import $ from 'jquery';

function imagePreview() {
  $('#take_picture').on('click', function() {
    document.getElementById('doc_auth_image').click();
  });
  $('#doc_auth_image').on('change', function(event) {
    const files = event.target.files;
    const image = files[0];
    const reader = new FileReader();
    reader.onload = function(file) {
      const img = new Image();
      img.onload = function () {
        let display_width = '500';
        let ratio = (this.height/this.width);
        img.width = display_width;
        img.height = (display_width*ratio);
        $('#target').html(img);
      };
      img.src = file.target.result;
      $('#target').html(img);
    };
    reader.readAsDataURL(image);
  });
}

document.addEventListener('DOMContentLoaded', imagePreview);
