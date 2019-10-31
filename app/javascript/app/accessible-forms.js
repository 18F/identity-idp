// once called the screen reader will not re-read the screen until page re-load
function preventScreenRead() {
  const body = document.querySelector('body');
  if (body) {
    body.setAttribute('aria-hidden', 'true');
  }
}

// attaches a submit listener to every form
function accessibleForms() {
  // if you do not want aria-hidden added to the body after submit,
  // then add the read-after-submit class to the form
  const forms = document.querySelectorAll('form:not(.read-after-submit)');
  if (forms) {
    [].slice.call(forms).forEach((element) => {
      element.addEventListener('submit', preventScreenRead);
    });
  }
}

document.addEventListener('DOMContentLoaded', accessibleForms);
