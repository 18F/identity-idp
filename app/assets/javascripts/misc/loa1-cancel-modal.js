import Modal from '../app/components/modal';

const modal = new Modal({el: '#sp-loa-cancel'});
const modalTrigger = document.getElementById('loa-cancel');
const modalDismiss = document.getElementById('loa-continue');

modalTrigger.addEventListener('click', () => {
  modal.show();
});

modalDismiss.addEventListener('click', () => {
  modal.hide();
});
