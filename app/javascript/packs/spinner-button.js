/**
 * @typedef SpinnerButtonElements
 *
 * @prop {HTMLDivElement} wrapper
 * @prop {HTMLImageElement} spinner
 * @prop {HTMLButtonElement|HTMLInputElement|HTMLLinkElement} button
 */

export class SpinnerButton {
  constructor(wrapper) {
    /** @type {SpinnerButtonElements} */
    this.elements = {
      wrapper,
      spinner: wrapper.querySelector('.spinner-button__spinner'),
      button: wrapper.querySelector('a,button:not([type]),[type="submit"]'),
    };

    this.bindEvents();
  }

  bindEvents() {
    this.elements.button.addEventListener('click', () => this.showSpinner());
  }

  showSpinner() {
    this.elements.wrapper.classList.add('spinner-button--spinner-active');
    this.elements.spinner.classList.remove('usa-sr-only');
  }
}

[...document.querySelectorAll('.spinner-button')].forEach((wrapper) => new SpinnerButton(wrapper));
