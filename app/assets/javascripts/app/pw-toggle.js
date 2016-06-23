function togglePw() {
  const input = document.querySelectorAll('input[type="password"]')[0];

  if (input) {
    input.parentNode.className += ' relative';

    const css = 'absolute right-0 btn p1 h6';
    const el = `<button type="button" id="pw-toggle" class="${css}">Show</button>`;
    input.insertAdjacentHTML('afterend', el);

    const toggle = document.getElementById('pw-toggle');
    toggle.addEventListener('click', function() {
      const isHidden = input.type === 'password';
      input.type = isHidden ? 'text' : 'password';
      toggle.innerHTML = isHidden ? 'Hide' : 'Show';
    });
  }
}


document.addEventListener('DOMContentLoaded', togglePw);
