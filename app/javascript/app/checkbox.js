function checkbox() {
  const styledCheckbox = document.querySelectorAll('input[type=checkbox]');

  if (styledCheckbox) {
    [].slice.call(styledCheckbox).forEach((input) => {
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
    });
  }
}


document.addEventListener('DOMContentLoaded', checkbox);
