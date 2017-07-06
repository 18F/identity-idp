const modal = new window.LoginGov.Modal({ el: '#reactivate-account-modal' });
const modalTrigger = document.getElementById('no-key-reactivate');
const modalDismiss = document.getElementById('no-key-reactivate-dismiss');

modalTrigger.addEventListener('click', (event) => {
  event.preventDefault();
  modal.show();
});

modalDismiss.addEventListener('click', (event) => {
  event.preventDefault();
  modal.hide();
});
