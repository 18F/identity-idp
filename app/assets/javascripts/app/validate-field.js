import 'classlist.js';


const msgs = {
  missing: 'Please fill in this field.',
  mismatch: 'Please match the requested format.',
};

function addInvalidMarkup(f) {
  f.setAttribute('aria-invalid', 'true');
  f.setAttribute('aria-describedby', `alert_${f.id}`);

  if (f.validity.valueMissing) f.setCustomValidity(msgs.missing);
  else if (f.validity.patternMismatch
    || f.validity.typeMismatch) f.setCustomValidity(msgs.mismatch);
  else f.setCustomValidity('');

  f.insertAdjacentHTML(
    'afterend',
    `<div role='alert' class='mt-tiny h6 red error-message' id='alert_${f.id}'>
      ${f.validationMessage}
    </div>`
  );
}

function removeInvalidMarkup(f) {
  f.parentNode.classList.remove('has-error');
  f.removeAttribute('aria-invalid');
  f.removeAttribute('aria-describedby');
}

function validateField(f) {
  f.classList.add('interacted');

  const parent = f.parentNode;
  const errorMsg = parent.querySelector('.error-message');

  if (errorMsg !== null) parent.removeChild(errorMsg);

  if (!f.validity.valid) addInvalidMarkup(f);
  else removeInvalidMarkup(f);
}

export default validateField;
