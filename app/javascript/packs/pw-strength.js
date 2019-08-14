import zxcvbn from 'zxcvbn';

const I18n = window.LoginGov.I18n;

// zxcvbn returns a strength score from 0 to 4
// we map those scores to:
// 1. a CSS class to the pw strength module
// 2. text describing the score
const scale = {
  0: ['pw-very-weak', I18n.t('instructions.password.strength.i')],
  1: ['pw-weak', I18n.t('instructions.password.strength.ii')],
  2: ['pw-so-so', I18n.t('instructions.password.strength.iii')],
  3: ['pw-good', I18n.t('instructions.password.strength.iv')],
  4: ['pw-great', I18n.t('instructions.password.strength.v')],
};

// fallback if zxcvbn lookup fails / field is empty
const fallback = ['pw-na', '...'];

function clearErrors() {
  const x = document.getElementsByClassName('error-message');
  if (x.length > 0) {
    x[0].innerHTML = '';
  }
}

function getStrength(z) {
  // override the strength value to 2 if the password is < 12
  if (!(z && z.password.length && z.password.length >= 12)) {
    if (z.score >= 3) {
      z.score = 2;
    }
  }
  return z && z.password.length ? scale[z.score] : fallback;
}

function getFeedback(z) {
  if (!z || z.score > 2) return '&nbsp;';

  const { warning, suggestions } = z.feedback;

  function lookup(str) {
    return I18n.t(`zxcvbn.feedback.${I18n.key(str)}`);
  }

  if (!warning && !suggestions.length) return '&nbsp;';
  if (warning) return lookup(warning);

  return `${suggestions.map(s => lookup(s)).join('')}`;
}

function disableSubmit(submitEl, length = 0, score = 0) {
  if (!submitEl) return;

  if (score < 3 || length < 12) {
    submitEl.setAttribute('disabled', true);
  } else {
    submitEl.removeAttribute('disabled');
  }
}

function analyzePw() {
  const userAgent = window.navigator.userAgent;
  const input = document.querySelector(
    '#password_form_password, #reset_password_form_password, #update_user_password_form_password',
  );
  const pwCntnr = document.getElementById('pw-strength-cntnr');
  const pwStrength = document.getElementById('pw-strength-txt');
  const pwFeedback = document.getElementById('pw-strength-feedback');
  const submit = document.querySelector('input[type="submit"]');
  const forbiddenPasswordsElement = document.querySelector('[data-forbidden-passwords]');
  const forbiddenPasswords = forbiddenPasswordsElement.dataset.forbiddenPasswords;

  disableSubmit(submit);

  // the pw strength module is hidden by default ("hide" CSS class)
  // (so that javascript disabled browsers won't see it)
  // thus, first step is unhiding it
  pwCntnr.className = '';

  function checkPasswordStrength(e) {
    const z = zxcvbn(e.target.value, JSON.parse(forbiddenPasswords));
    const [cls, strength] = getStrength(z);
    const feedback = getFeedback(z);
    pwCntnr.className = cls;
    pwStrength.innerHTML = strength;
    pwFeedback.innerHTML = feedback;

    clearErrors();
    disableSubmit(submit, z.password.length, z.score);
  }

  if (/(msie 9)/i.test(userAgent)) {
    input.addEventListener('keyup', checkPasswordStrength);
  }

  input.addEventListener('input', checkPasswordStrength);
}

document.addEventListener('DOMContentLoaded', analyzePw);
