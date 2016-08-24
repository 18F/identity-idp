function togglePw() {
  const input = document.querySelectorAll('input[type="password"]')[0];

  if (input) {
    input.parentNode.className += ' relative';

    const el = `
      <div class="top-0 right-0 absolute">
        <label class="checkbox">
          <input id="pw-toggle" type="checkbox">
          <span class="indicator"></span>
          Show password
        </label>
      </div>`;
    input.insertAdjacentHTML('afterend', el);

    const toggle = document.getElementById('pw-toggle');
    toggle.addEventListener('change', function() {
      input.type = toggle.checked ? 'text' : 'password';
    });
  }
}


document.addEventListener('DOMContentLoaded', togglePw);
