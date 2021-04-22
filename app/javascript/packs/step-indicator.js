import StepIndicator from '@18f/identity-step-indicator';

const wrappers = Array.from(document.querySelectorAll('.step-indicator'));
wrappers.forEach((wrapper) => new StepIndicator(/** @type {HTMLElement} */ (wrapper)).bind());
