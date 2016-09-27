function togglePw() {
  const inputs = document.querySelectorAll('input[type="password"]');

  if (inputs) {
    for (let i = 0; i < inputs.length; i++) {
      const input = inputs[i];

      input.parentNode.className += ' relative';

      const el = `
        <div class="top-0 right-0 absolute">
          <label class="checkbox" for="pw-toggle-${i}">
            <input id="pw-toggle-${i}" type="checkbox">
            <span class="indicator"></span>
            Show password
          </label>
        </div>`;
      input.insertAdjacentHTML('afterend', el);

      const toggle = document.getElementById(`pw-toggle-${i}`);
      toggle.addEventListener('change', function() {
        input.type = toggle.checked ? 'text' : 'password';
      });
    }
  }
}


document.addEventListener('DOMContentLoaded', togglePw);
