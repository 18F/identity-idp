import zxcvbn from 'zxcvbn';

const I18n = window.LoginGov.I18n;

// zxcvbn returns a strength score from 0 to 4
// we map those scores to:
// 1. a CSS class to the pw strength module
// 2. text describing the score
function getStrength(z) {
  const scale = {
    0: ['pw-very-weak', I18n.t('instructions.password.strength.i')],
    1: ['pw-weak', I18n.t('instructions.password.strength.ii')],
    2: ['pw-so-so', I18n.t('instructions.password.strength.iii')],
    3: ['pw-good', I18n.t('instructions.password.strength.iv')],
    4: ['pw-great', I18n.t('instructions.password.strength.v')],
  };

  // fallback if zxcvbn lookup fails / field is empty
  const fallback = ['pw-na', '...'];

  return z && z.password.length ? scale[z.score] : fallback;
}


function getFeedback(z) {
  if (!z || z.score > 2) return '';

  const { warning, suggestions } = z.feedback;
  function lookup(str) {
    const strFormatted = str.replace(/\./g, '_');
    return I18n.t(`zxcvbn.feedback.${strFormatted}`);
  }

  if (!warning && !suggestions.length) return '';
  if (warning) return lookup(warning);

  return `${suggestions.map(function(s) { return lookup(s); }).join('; ')}`;
}

function disableSubmit(submitEl, score) {
  if (!submitEl) return;

  if (!score || score < 3) {
    submitEl.setAttribute('disabled', true);
  } else {
    submitEl.removeAttribute('disabled');
  }
}

function analyzePw() {
  const input = document.querySelector(
    '#password_form_password, #reset_password_form_password, #update_user_password_form_password'
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

  input.addEventListener('keyup', function(e) {
    const z = zxcvbn(e.target.value);
    const [cls, strength] = getStrength(z);
    const feedback = getFeedback(z);
    pwCntnr.className = cls;
    pwStrength.innerHTML = strength;
    pwFeedback.innerHTML = feedback;

    disableSubmit(submit, z.score);
  });
}

document.addEventListener('DOMContentLoaded', analyzePw);
