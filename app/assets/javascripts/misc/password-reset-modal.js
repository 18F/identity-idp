const modal = new window.LoginGov.Modal({ el: '#password-reset-modal' });
const modalTrigger = document.getElementById('password-reset');

modalTrigger.addEventListener('click', (event) => {
  event.preventDefault();
  modal.show();
});
