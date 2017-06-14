const modal = new window.LoginGov.Modal({ el: '#reactivate-account-modal' });
const modalTrigger = document.getElementById('no-key-reactivate');

modalTrigger.addEventListener('click', (event) => {
  event.preventDefault();
  modal.show();
});
