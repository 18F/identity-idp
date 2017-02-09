import 'classlist.js';

function verifyModal() {
  const flash = document.querySelector('.alert');
  const modal = document.querySelector('.modal-cntnr');
  const close = document.getElementById('js-close-modal');

  if (flash) flash.classList.add('hide');
  if (modal) modal.classList.remove('hide');

  if (close) {
    close.addEventListener('click', function() {
      modal.classList.add('hide');
    });
  }
}


document.addEventListener('DOMContentLoaded', verifyModal);
