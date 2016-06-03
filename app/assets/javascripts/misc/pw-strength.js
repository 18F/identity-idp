import zxcvbn from 'zxcvbn';


// zxcvbn returns a strength score from 0 to 4
// we map those scores to:
// 1. a CSS class to the pw strength module
// 2. text describing the score
const scale = {
  0: ['pw-very-weak', 'Very weak'],
  1: ['pw-weak', 'Weak'],
  2: ['pw-so-so', 'So-so'],
  3: ['pw-good', 'Good'],
  4: ['pw-great', 'Great'],
};

// fallback result if pw field is empty or zxcvbn lookup fails
const fallback = ['pw-na', 'Password strength'];


function analyzePw() {
  const input = document.getElementById('password_form_password');
  const pwCntnr = document.getElementById('pw-strength-cntnr');
  const pwTxt = document.getElementById('pw-feedback');

  // the pw strength module is hidden by default ("hide" CSS class)
  // (so that javascript disabled browsers won't see it)
  // thus, first step is unhiding it
  pwCntnr.className = '';

  input.addEventListener('keyup', function(e) {
    const val = e.target.value;
    const z = zxcvbn(val);
    const result = val.length && z ? scale[z.score] : fallback;

    pwCntnr.className = result[0];
    pwTxt.innerHTML = result[1];
  });
}


document.addEventListener('DOMContentLoaded', analyzePw);
