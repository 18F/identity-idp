import 'classlist.js'
import H5F from 'h5f';


function validateInit() {
  var form = document.querySelector("form");
  H5F.setup(form);
  validate(form);
}

function validate(form) {

  // remove default browser validation messages
  form.addEventListener("invalid", function(e) {
    e.preventDefault();
  }, true);

  form.addEventListener("submit", function(e) {
    if (!this.checkValidity()) {
        e.preventDefault();
    }
  });

  var submitButton = form.querySelector("input[type=submit]");
  submitButton.addEventListener("click", function(e) {
    validateForm(form);
  });

  document.addEventListener("change", function(e) {
    validateField(e.target);
  }, false);

}

function validateField(field) {

  var parent = field.parentNode,
    errorMessage = parent.querySelector(".error-message");

  if (errorMessage != null) {
      parent.removeChild(errorMessage);
  }

  if (!field.validity.valid) {
    field.setAttribute('aria-invalid', 'true');
    field.setAttribute('aria-describedby', 'alert_' + field.id);
    field.classList.add("border-red");
      parent.insertAdjacentHTML( "beforeend",
        "<div role='alert' class='error-message hide' id='alert_" +
        field.id + "'>" + field.validationMessage + "</div>");
  } else {
    field.removeAttribute('aria-invalid');
    field.removeAttribute('aria-describedby');
    field.classList.remove("border-red");
  }

}

function validateForm(form) {

  var invalidFields = form.querySelectorAll(":invalid"),
      validFields = form.querySelectorAll(":valid"),
      errorMessages = form.querySelectorAll(".error-message"),
      parent;

  for (var i = 0; i < errorMessages.length; i++) {
    errorMessages[i].parentNode.removeChild(errorMessages[i]);
  }

  for (var i = 0; i < validFields.length; i++) {
    validFields[i].removeAttribute('aria-invalid');
    validFields[i].removeAttribute('aria-describedby');
    validFields[i].classList.remove("border-red");
  }

  for (var i = 0; i < invalidFields.length; i++) {
    invalidFields[i].setAttribute('aria-invalid', 'true');
    invalidFields[i].setAttribute('aria-describedby', 'alert_' + invalidFields[i].id);
    invalidFields[i].classList.add("border-red");
    validateMessages(invalidFields[i]);
    parent = invalidFields[i].parentNode;
    parent.insertAdjacentHTML( "beforeend",
      "<div role='alert' class='error-message hide' id='alert_" +
      invalidFields[i].id + "'>" + invalidFields[i].validationMessage + "</div>" );
  }

  // put focus on first invalid input
  if (invalidFields.length > 0) {
      invalidFields[0].focus();
  }

}

// standardize validation messages across browsers
function validateMessages(field) {
  if(field.validity.valueMissing) {
    return field.setCustomValidity("Please fill in all required fields.");
  } else if (field.validity.typeMismatch) {
    return field.setCustomValidity("Please match the requested format.");
  } else {
    return field.setCustomValidity("");
  }
}

document.addEventListener('DOMContentLoaded', validateInit);
