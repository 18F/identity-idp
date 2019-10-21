const I18n = window.LoginGov.I18n;

function checkbox() {
  const styledCheckbox = document.querySelectorAll("input[type=checkbox]");

  if (styledCheckbox) {
    [].slice.call(styledCheckbox).forEach((input, i) => {
      input.addEventListener( 'change', function() {
        let indicator = input.parentNode.querySelector(".indicator")
        if (indicator) {
          if(this.checked) {
              indicator.classList.add("indicator-checked");
          } else {
              indicator.classList.remove("indicator-checked");
          }
        }
      });
    });
  }
}


document.addEventListener('DOMContentLoaded', checkbox);
