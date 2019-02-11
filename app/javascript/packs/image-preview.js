import $ from 'jquery';

function imagePreview() {
  $('#doc_auth_image').on('change', function(event) {
    var files = event.target.files;
    var image = files[0];
    var reader = new FileReader();
    reader.onload = function(file) {
      var img = new Image();
      img.src = file.target.result;
      // document.getElementById('target').innerHTML = img;
      $('#target').html(img);
    }
    reader.readAsDataURL(image);
  });
}

document.addEventListener('DOMContentLoaded', imagePreview);
