import 'classlist.js';

const I18n = window.LoginGov.I18n;

function addInvalidMarkup(f) {
  f.setAttribute('aria-invalid', 'true');
  f.setAttribute('aria-describedby', `alert_${f.id}`);

  if (f.validity.valueMissing) f.setCustomValidity(I18n.t('errors.messages.missing_field'));
  else if (f.validity.typeMismatch &&
    f.type === 'email') f.setCustomValidity(I18n.t('valid_email.validations.email.invalid'));
  else if (f.validity.patternMismatch
    || f.validity.typeMismatch) f.setCustomValidity(I18n.t('errors.messages.format_mismatch'));

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
  f.setCustomValidity('');
  f.classList.add('interacted');

  const parent = f.parentNode;
  const errorMsg = parent.querySelector('.error-message');

  if (errorMsg !== null) parent.removeChild(errorMsg);

  if (!f.validity.valid) addInvalidMarkup(f);
  else removeInvalidMarkup(f);
}

export default validateField;
