import MaskedTextToggle from '@18f/identity-masked-text-toggle';

const wrappers = document.querySelectorAll('.masked-text__toggle');
wrappers.forEach((toggle) => new MaskedTextToggle(/** @type {HTMLInputElement} */ (toggle)).bind());
