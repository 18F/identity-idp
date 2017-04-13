const I18n = window.LoginGov.I18n;

function togglePw() {
  const inputs = document.querySelectorAll('input[type="password"]');

  if (inputs) {
    [].slice.call(inputs).forEach((input, i) => {
      input.parentNode.classList.add('relative');

      const el = `
        <div class="top-n24 right-0 absolute">
          <label class="btn-border" for="pw-toggle-${i}">
            <div class="checkbox">
              <input id="pw-toggle-${i}" type="checkbox">
              <span class="indicator"></span>
              ${I18n.t('forms.passwords.show')}
            </div>
          </label>
        </div>`;
      input.insertAdjacentHTML('afterend', el);

      const toggle = document.getElementById(`pw-toggle-${i}`);
      toggle.addEventListener('change', function() {
        input.type = toggle.checked ? 'text' : 'password';
      });
    });
  }
}


document.addEventListener('DOMContentLoaded', togglePw);
