/* eslint-disable no-var, vars-on-top */

document.addEventListener('DOMContentLoaded', function() {
  const lookupTxt = '<small class="i18n-anchor">';
  const inputs = document.querySelectorAll('input[type="submit"]');

  if (inputs) {
    [].slice.call(inputs).forEach((input) => {
      const val = input.value;
      const i18nStart = val.indexOf(lookupTxt);

      if (i18nStart > -1) {
        input.insertAdjacentHTML('afterend', val.slice(i18nStart));
        input.value = val.slice(0, i18nStart);
      }
    });
  }
});
