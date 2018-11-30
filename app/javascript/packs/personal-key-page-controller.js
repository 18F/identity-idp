import base32Crockford from 'base32-crockford-browser';

const modalSelector = '#personal-key-confirm';
const modal = new window.LoginGov.Modal({ el: modalSelector });

const personalKeyContainer = document.getElementById('personal-key');
const personalKeyWords = [].slice.call(document.querySelectorAll('[data-personal-key]'));
const formEl = document.getElementById('confirm-key');
const input = formEl.querySelector('input[type="text"]');
const modalTrigger = document.querySelector('[data-toggle="modal"]');
const modalDismiss = document.querySelector('[data-dismiss="personal-key-confirm"]');

let isInvalidForm = false;

function scrapePersonalKey() {
  const keywords = [];

  personalKeyWords.forEach((keyword) => {
    keywords.push(keyword.innerHTML);
  });

  return keywords.join('-').toUpperCase();
}

const personalKey = scrapePersonalKey();

// The following methods are strictly fallbacks for IE < 11. There is limited
// support for HTML5 validation attributes in those browsers
function setInvalidHTML() {
  if (isInvalidForm) return;

  document.getElementById('personal-key-alert').classList.remove('display-none');

  isInvalidForm = true;
}

function unsetInvalidHTML() {
  document.getElementById('personal-key-alert').classList.add('display-none');

  isInvalidForm = false;
}

function resetForm() {
  formEl.reset();
  unsetInvalidHTML();
}

function formatInput(value) {
  // Coerce mistaken user input from 'problem' letters:
  // https://en.wikipedia.org/wiki/Base32#Crockford.27s_Base32
  value = base32Crockford.decode(value);
  value = base32Crockford.encode(value);

  // Add back the dashes
  value = value.toString().match(/.{4}/g).join('-');

  // And uppercase
  return value.toUpperCase();
}

function handleSubmit(event) {
  event.preventDefault();

  // As above, in case browser lacks HTML5 validation (e.g., IE < 11)
  if (input.value.length < 19) {
    setInvalidHTML();
    return;
  }

  const value = formatInput(input.value);

  if (value === personalKey) {
    unsetInvalidHTML();
    // Recovery code page, without js enabled, has a form submission that posts
    // to the server with no body.
    // Mimic that here.
    formEl.removeEventListener('submit', handleSubmit);
    formEl.submit();
  } else {
    setInvalidHTML();
  }
}

function show(event) {
  event.preventDefault();

  modal.on('show', function() {
    input.focus();
    personalKeyContainer.classList.add('invisible');
  });

  modal.show();
}

function hide() {
  modal.on('hide', function() {
    resetForm();
    personalKeyContainer.classList.remove('invisible');
  });

  modal.hide();
}

modalTrigger.addEventListener('click', show);
modalDismiss.addEventListener('click', hide);
formEl.addEventListener('submit', handleSubmit);
