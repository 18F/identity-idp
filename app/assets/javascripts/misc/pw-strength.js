import zxcvbn from 'zxcvbn';


// zxcvbn returns a strength score from 0 to 4
// we map those scores to:
// 1. a CSS class to the pw strength module
// 2. text describing the score
function getStrength(z) {
  const scale = {
    0: ['pw-very-weak', 'Very weak'],
    1: ['pw-weak', 'Weak'],
    2: ['pw-so-so', 'So-so'],
    3: ['pw-good', 'Good'],
    4: ['pw-great', 'Great'],
  };

  // fallback if zxcvbn lookup fails / field is empty
  const fallback = ['pw-na', 'Password strength'];

  return z && z.password.length ? scale[z.score] : fallback;
}


function getFeedback(z) {
  const goodMsg = 'This is a strong password';
  const fallback = 'Please choose a strong, secure password';

  if (!z) return fallback;
  if (z.score > 2) return goodMsg;

  const { warning, suggestions } = z.feedback;
  if (!warning && !suggestions.length) return fallback;

  let msg = warning ? `<div class='mb1 h5 bold'>${warning}</div>` : '';
  msg += suggestions.length ? `
    <div class='bold'>Suggestions:</div>
    ${suggestions.map(function(s) { return s; }).join('<br>')}
  ` : '';

  return msg;
}


function analyzePw() {
  const input = document.getElementById('password_form_password');
  const pwCntnr = document.getElementById('pw-strength-cntnr');
  const pwStrength = document.getElementById('pw-strength-txt');
  const pwFeedback = document.getElementById('pw-strength-feedback');

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
  });
}


document.addEventListener('DOMContentLoaded', analyzePw);
