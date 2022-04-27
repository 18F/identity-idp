class ClipboardButtonElement extends HTMLElement {
  button: HTMLButtonElement;

  connectedCallback() {
    this.button = this.querySelector('button')!;

    this.button.addEventListener('click', () => this.writeToClipboard());
  }

  /**
   * Returns the text to be copied to the clipboard.
   */
  get clipboardText(): string {
    return this.dataset.clipboardText || '';
  }

  /**
   * Writes the element's clipboard text to the clipboard.
   */
  writeToClipboard() {
    navigator.clipboard.writeText(this.clipboardText);
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-clipboard-button': ClipboardButtonElement;
  }
}

if (!customElements.get('lg-clipboard-button')) {
  customElements.define('lg-clipboard-button', ClipboardButtonElement);
}

export default ClipboardButtonElement;
