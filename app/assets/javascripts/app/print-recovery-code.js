const openSystemPrintDialog = (event) => {
  event.preventDefault();
  window.print();
};

const enableRecoveryCodePrintButton = () => {
  const buttonNodes = document.querySelectorAll('[data-print]');
  const buttons = [].slice.call(buttonNodes);
  const { userAgent } = navigator;

  buttons.forEach((button) => {
    button.addEventListener('click', openSystemPrintDialog);
  });
};

document.addEventListener('DOMContentLoaded', enableRecoveryCodePrintButton);
