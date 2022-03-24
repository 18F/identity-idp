class MaskedTextToggle {
  /**
   * @param {HTMLInputElement} toggle
   */
  constructor(toggle) {
    this.elements = {
      toggle,
      texts: /** @type {NodeListOf<HTMLElement>} */ (
        document.querySelectorAll(`#${toggle.getAttribute('aria-controls')} .masked-text__text`)
      ),
    };
  }

  bind() {
    this.elements.toggle.addEventListener('change', () => this.toggleTextVisibility());
    this.toggleTextVisibility();
  }

  toggleTextVisibility() {
    const { toggle, texts } = this.elements;
    const isMasked = !toggle.checked;
    texts.forEach((text) => {
      text.classList.toggle('display-none', text.dataset.masked !== isMasked.toString());
    });
  }
}

export default MaskedTextToggle;
