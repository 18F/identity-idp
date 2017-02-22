import 'classlist.js';

function toggleButton() {
  const accordion = document.querySelector('.accordion');

  if (accordion) {
    const controls = [].slice.call(accordion.querySelectorAll('[aria-controls]'));
    const button = document.querySelector('.js-toggle-button');

    controls.forEach((control) => {
      control.addEventListener('click', function() {
        const expandedState = accordion.getAttribute('aria-expanded');

        if (expandedState === 'false') {
          button.classList.add('display-none');
        } else if (expandedState === 'true') {
          button.classList.remove('display-none');
        }
      });
    });
  }
}

document.addEventListener('DOMContentLoaded', toggleButton);
