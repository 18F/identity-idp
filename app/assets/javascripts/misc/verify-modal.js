import 'classlist.js';
import { Modal } from '../app/components/index';

function verifyModal() {
  const flash = document.querySelector('.alert');
  const modalSelector = document.getElementById('verification-modal');
  const modal = new Modal({ el: '#verification-modal' });
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
