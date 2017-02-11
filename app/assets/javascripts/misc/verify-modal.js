import 'classlist.js';

function verifyModal() {
  const flash = document.querySelector('.alert');
  const modal = document.querySelector('.modal-cntnr');
  const close = document.getElementById('js-close-modal');

  if (flash) flash.classList.add('display-none');
  if (modal) modal.classList.remove('display-none');

  if (close) {
    close.addEventListener('click', function() {
      modal.classList.add('display-none');
    });
  }
}


document.addEventListener('DOMContentLoaded', verifyModal);
