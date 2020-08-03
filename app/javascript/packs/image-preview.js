import $ from 'jquery';

function imagePreview() {
  $('#take_picture').on('click', function () {
    document.getElementById('doc_auth_image').click();
  });
  $('#doc_auth_image').on('change', function (event) {
    $('.simple_form .alert-error').hide();
    $('.simple_form .alert-notice').hide();
    const { files } = event.target;
    const image = files[0];
    const reader = new FileReader();
    reader.onload = function (file) {
      const img = new Image();
      img.onload = function () {
        const displayWidth = '460';
        const ratio = this.height / this.width;
        img.width = displayWidth;
        img.height = displayWidth * ratio;
        $('#target').html(img);
      };
      img.src = file.target.result;
      $('#target').html(img);
    };
    reader.readAsDataURL(image);
  });
}

document.addEventListener('DOMContentLoaded', imagePreview);

function imagePreviewFunction(imageType) {
  const imageId = `doc_auth_${imageType}_image`;
  const imageIdSelector = `#${imageId}`;
  const takeImageSelector = `#take_${imageType}_picture`;
  const targetIdSelector = `#${imageType}_target`;

  return function () {
    $(takeImageSelector).on('click', function () {
      document.getElementById(imageId).click();
    });
    $(imageIdSelector).on('change', function (event) {
      $('.simple_form .alert-error').hide();
      $('.simple_form .alert-notice').hide();
      const { files } = event.target;
      const image = files[0];
      const reader = new FileReader();
      reader.onload = function (file) {
        const img = new Image();
        img.onload = function () {
          const displayWidth = '460';
          const ratio = this.height / this.width;
          img.width = displayWidth;
          img.height = displayWidth * ratio;
          $(targetIdSelector).html(img);
        };
        img.src = file.target.result;
        $(targetIdSelector).html(img);
      };
      reader.readAsDataURL(image);
    });
  };
}

const frontImagePreview = imagePreviewFunction('front');
const backImagePreview = imagePreviewFunction('back');
const selfieImagePreview = imagePreviewFunction('selfie');

document.addEventListener('DOMContentLoaded', frontImagePreview);
document.addEventListener('DOMContentLoaded', backImagePreview);
document.addEventListener('DOMContentLoaded', selfieImagePreview);
