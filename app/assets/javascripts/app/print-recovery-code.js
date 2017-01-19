import isMobileUserAgent from './utils/mobile-user-agent';

const openSystemPrintDialog = () =>
  window.print();

const enableRecoveryCodePrintButton = () => {
  const buttonNodes = document.querySelectorAll('[data-print]');
  const buttons = [].slice.call(buttonNodes);
  const { userAgent } = navigator;

  if (isMobileUserAgent(userAgent)) {
    buttons.forEach(button => {
      /* eslint-disable no-param-reassign */
      button.style.display = 'none';
    });
  }

  buttons.forEach((button) => {
    button.addEventListener('click', openSystemPrintDialog);
  });
};

document.addEventListener('DOMContentLoaded', enableRecoveryCodePrintButton);
