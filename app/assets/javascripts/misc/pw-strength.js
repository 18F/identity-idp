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
    4: ['pw-great', 'Great!'],
  };

  // fallback if zxcvbn lookup fails / field is empty
  const fallback = ['pw-na', '...'];

  return z && z.password.length ? scale[z.score] : fallback;
}


function getFeedback(z) {
  if (!z || z.score > 2) return '';

  const { warning, suggestions } = z.feedback;
  if (!warning && !suggestions.length) return '';

  return warning || `${suggestions.map(function(s) { return s; }).join('; ')}`;
}


function analyzePw() {
  const input = document.querySelector(
    '#password_form_password, #update_user_password_form_password'
  );
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
