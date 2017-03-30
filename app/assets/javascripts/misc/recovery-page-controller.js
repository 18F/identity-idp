import { Modal } from '../app/components/index';

const modalSelector = '#personal-key-confirm';
const modal = new Modal({ el: modalSelector });

const recoveryCodeContainer = document.getElementById('recovery-code');
const recoveryWords = [].slice.call(document.querySelectorAll('[data-recovery]'));
const formEl = document.getElementById('confirm-key');
const inputs = [].slice.call(formEl.elements).filter((el) => el.type === 'text');
const modalTrigger = document.querySelector('[data-toggle="modal"]');
const modalDismiss = document.querySelector('[data-dismiss="personal-key-confirm"]');

let isInvalidForm = false;

// The following methods are strictly fallbacks for IE < 11. There is limited
// support for HTML5 validation attributes in those browsers
// TODO: Potentially investigate readding client-side JS errors in a robust way
function setInvalidHTML() {
  if (isInvalidForm) return;

  document.getElementById('recovery-code-alert').classList.remove('display-none');

  isInvalidForm = true;
}

function unsetInvalidHTML() {
  document.getElementById('recovery-code-alert').classList.add('display-none');

  isInvalidForm = false;
}

function resetForm() {
  formEl.reset();
  unsetInvalidHTML();
}

function handleSubmit(event) {
  event.preventDefault();

  const invalidMatches = inputs.reduce(function(accumulator, input, index) {
    const value = input.value;

    if (value.toUpperCase() === recoveryWords[index].innerHTML.replace(/\s+/, '').toUpperCase()) {
      return accumulator;
    }

    accumulator.push(value);

    return accumulator;
  }, []);

  if (!invalidMatches.length) {
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
    inputs[0].focus();
    recoveryCodeContainer.classList.add('invisible');
  });

  modal.show();
}

function hide() {
  modal.on('hide', function() {
    resetForm();
    recoveryCodeContainer.classList.remove('invisible');
  });

  modal.hide();
}

modalTrigger.addEventListener('click', show);
modalDismiss.addEventListener('click', hide);
formEl.addEventListener('submit', handleSubmit);
