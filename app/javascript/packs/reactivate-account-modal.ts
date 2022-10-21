import type { ModalElement } from '@18f/identity-modal';

const modal = document.querySelector<ModalElement>('lg-modal.reactivate-account-modal');
const modalTrigger = document.getElementById('no-key-reactivate');

modalTrigger?.addEventListener('click', (event) => {
  event.preventDefault();
  modal?.show();
});
