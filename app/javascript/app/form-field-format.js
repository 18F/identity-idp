import Cleave from 'cleave.js';

/* eslint-disable no-new */
function formatForm() {
  if (document.querySelector('.dob')) {
    new Cleave('.dob', {
      date: true,
      datePattern: ['m', 'd', 'Y'],
    });
  }

  if (document.querySelector('.personal-key')) {
    new Cleave('.personal-key', {
      blocks: [4, 4, 4, 4],
      delimiter: '-',
    });
  }

  if (document.querySelector('.backup-code')) {
    new Cleave('.backup-code', {
      blocks: [4, 4, 4],
      delimiter: '-',
    });
  }

  if (document.querySelector('.zipcode')) {
    new Cleave('.zipcode', {
      numericOnly: true,
      blocks: [5, 4],
      delimiter: '-',
      delimiterLazyShow: true,
    });
  }

  if (document.querySelector('.mfa')) {
    new Cleave('.mfa', {
      numericOnly: true,
      blocks: [6],
    });
  }
}

document.addEventListener('DOMContentLoaded', formatForm);
