import { Modal } from '../app/components/index';

const modal = new Modal({ el: '#cancel-action-modal' });
const modalTrigger = document.getElementById('auth-flow-cancel');
const modalDismiss = document.getElementById('loa-continue');

modalTrigger.addEventListener('click', (event) => {
  event.preventDefault();
  modal.show();
});

modalDismiss.addEventListener('click', () => {
  modal.hide();
});
