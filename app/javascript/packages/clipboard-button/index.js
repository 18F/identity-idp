export class ClipboardButton extends HTMLElement {
  connectedCallback() {
    /** @type {HTMLButtonElement?} */
    this.button = this.querySelector('button');
    this.clipboardText = this.dataset.clipboardText;

    this.button?.addEventListener('click', () => this.writeToClipboard());
  }

  writeToClipboard() {
    if (this.clipboardText) {
      navigator.clipboard.writeText(this.clipboardText);
    }
  }
}
