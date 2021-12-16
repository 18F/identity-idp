export class ClipboardButton extends HTMLElement {
  connectedCallback() {
    /** @type {HTMLButtonElement?} */
    this.button = this.querySelector('button');

    this.button?.addEventListener('click', () => this.writeToClipboard());
  }

  /**
   * Returns the text to be copied to the clipboard.
   *
   * @return {string}
   */
  get clipboardText() {
    return this.dataset.clipboardText || '';
  }

  /**
   * Writes the element's clipboard text to the clipboard.
   */
  writeToClipboard() {
    navigator.clipboard.writeText(this.clipboardText);
  }
}
