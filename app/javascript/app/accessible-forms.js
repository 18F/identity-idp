// once called the screen reader will not re-read the screen until page re-load
function preventScreenRead() {
  const body = document.querySelector('body');
  if (body) {
    body.setAttribute('aria-hidden', 'true');
  }
}

// attaches a submit listener to every form
function accessibleForms() {
  const forms = document.querySelectorAll('form');
  if (forms) {
    [].slice.call(forms).forEach((element) => {
      element.addEventListener('submit', preventScreenRead);
    });
  }
}

document.addEventListener('DOMContentLoaded', accessibleForms);
