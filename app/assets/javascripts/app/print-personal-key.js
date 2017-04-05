const openSystemPrintDialog = (event) => {
  event.preventDefault();
  window.print();
};

const enablePersonalKeyPrintButton = () => {
  const buttonNodes = document.querySelectorAll('[data-print]');
  const buttons = [].slice.call(buttonNodes);

  buttons.forEach((button) => {
    button.addEventListener('click', openSystemPrintDialog);
  });
};

document.addEventListener('DOMContentLoaded', enablePersonalKeyPrintButton);
