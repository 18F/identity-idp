document.addEventListener('DOMContentLoaded', () => {
  const form = document.querySelector('form');
  if (form && window.onbeforeunload) {
    form.addEventListener('submit', () => {
      if (form.checkValidity()) window.onbeforeunload = false;
    });
  }
});
