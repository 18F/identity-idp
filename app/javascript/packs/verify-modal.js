import 'classlist.js';

function verifyModal() {
  const flash = document.querySelector('.alert');
  const modalSelector = document.getElementById('verification-modal');
  const modal = new window.LoginGov.Modal({ el: '#verification-modal' });
  const modalDismiss = document.getElementById('js-close-modal');

  if (flash) flash.classList.add('display-none');
  if (modalSelector) modal.show();

  if (modalDismiss) {
    modalDismiss.addEventListener('click', () => {
      modal.hide();
    });
  }
}


document.addEventListener('DOMContentLoaded', verifyModal);
