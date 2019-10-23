function checkbox() {
  const styledCheckbox = document.querySelectorAll('input[type=checkbox]');
  if (styledCheckbox) {
    [].slice.call(styledCheckbox).forEach((input) => {
      // display checkbox with checkmark in high contrast mode
      input.addEventListener('change', function() {
        const indicator = input.parentNode.querySelector('.indicator');
        if (indicator) {
          if (this.checked) {
            indicator.classList.add('indicator-checked');
          } else {
            indicator.classList.remove('indicator-checked');
          }
        }
      });
      // allow checkbox label to be read by screen readers
      const label = input.parentNode.textContent.trim();
      if (label) {
        input.setAttribute('aria-label', label);
      }
    });
  }
}


document.addEventListener('DOMContentLoaded', checkbox);
