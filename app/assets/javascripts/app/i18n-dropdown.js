import 'classlist.js';

document.addEventListener('DOMContentLoaded', () => {
  const mobileLink = document.querySelector('.i18n-mobile-toggle');
  const mobileDropdown = document.querySelector('.i18n-mobile-dropdown');
  const desktopLink = document.querySelector('.i18n-desktop-toggle');
  const desktopDropdown = document.querySelector('.i18n-desktop-dropdown');

  function initDropdown (trigger, dropdown) {
    trigger.addEventListener('click', function() {
      this.classList.toggle('focused');
      dropdown.classList.toggle('focused');
    });
  }

  if (mobileLink) initDropdown(mobileLink, mobileDropdown);
  if (desktopLink) initDropdown(desktopLink, desktopDropdown);
});
