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

function getStrength(z) {
  return z && z.password.length ? scale[z.score] : fallback;
}

function getFeedback(z) {
  if (!z || z.score > 2) return '';

  const { warning, suggestions } = z.feedback;

  function lookup(str) {
    return I18n.t(`zxcvbn.feedback.${I18n.key(str)}`);
  }

  if (!warning && !suggestions.length) return '';
  if (warning) return lookup(warning);

  return `${suggestions.map(s => lookup(s)).join('. ')}`;
}

function disableSubmit(submitEl, score = 0) {
  if (!submitEl) return;

  if (score < 3) {
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

  disableSubmit(submit);

  // the pw strength module is hidden by default ("hide" CSS class)
  // (so that javascript disabled browsers won't see it)
  // thus, first step is unhiding it
  pwCntnr.className = '';

  function checkPasswordStrength(e) {
    const z = zxcvbn(e.target.value);
    const [cls, strength] = getStrength(z);
    const feedback = getFeedback(z);
    pwCntnr.className = cls;
    pwStrength.innerHTML = strength;
    pwFeedback.innerHTML = feedback;

    disableSubmit(submit, z.score);
  }

  if (/(msie 9)/i.test(userAgent)) {
    input.addEventListener('keyup', checkPasswordStrength);
  }

  input.addEventListener('input', checkPasswordStrength);
}

document.addEventListener('DOMContentLoaded', analyzePw);
