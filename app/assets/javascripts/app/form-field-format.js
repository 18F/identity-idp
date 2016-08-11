import Formatter from 'formatter.js-pebble';


function formatForm() {
  const formats = [
    ['input[type="tel"]', '+1 ({{999}}) {{999}}-{{9999}}'],
  ];

  formats.forEach(function(f) {
    const [el, ptrn] = f;
    const input = document.querySelector(el);
    if (input) {
      /* eslint-disable no-new */
      new Formatter(input, { pattern: ptrn });
    }
  });
}


document.addEventListener('DOMContentLoaded', formatForm);
