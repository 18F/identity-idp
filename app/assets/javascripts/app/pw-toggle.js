function togglePw() {
  const input = document.querySelectorAll('input[type="password"]')[0];

  if (input) {
    input.parentNode.className += ' relative';

    const el = `
      <label class="pw-toggle-cntnr absolute top-0 right-0 h6">
        <input class="h6" id="pw-toggle" type="checkbox"> Show password
      </label>`;
    input.insertAdjacentHTML('afterend', el);

    const toggle = document.getElementById('pw-toggle');
    toggle.addEventListener('change', function() {
      input.type = toggle.checked ? 'text' : 'password';
    });
  }
}


document.addEventListener('DOMContentLoaded', togglePw);
