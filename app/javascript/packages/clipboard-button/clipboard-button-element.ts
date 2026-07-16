const COPIED_TIMEOUT_MS = 1000;

class ClipboardButtonElement extends HTMLElement {
  button: HTMLButtonElement;

  #copied = false;

  #copiedTimeout?: number;

  connectedCallback() {
    this.button = this.querySelector('button')!;
    this.button.addEventListener('click', () => this.handleClick());
  }

  disconnectedCallback() {
    window.clearTimeout(this.#copiedTimeout);
  }

  get clipboardText(): string {
    return this.getAttribute('clipboard-text')!;
  }

  get tooltipText(): string {
    return this.getAttribute('tooltip-text')!;
  }

  handleClick() {
    navigator.clipboard.writeText(this.clipboardText);
    this.showCopied();
  }

  showCopied() {
    if (this.#copied) {
      return;
    }

    const icon = this.button.querySelector('.ads-icon');
    const successIcon = this.querySelector('template')?.content.firstElementChild;
    if (!icon || !successIcon) {
      return;
    }

    this.#copied = true;
    const originalHTML = this.button.innerHTML;
    const originalClassName = this.button.className;

    icon.replaceWith(successIcon.cloneNode(true));
    this.button.childNodes.forEach((node) => {
      if (node.nodeType === Node.TEXT_NODE && node.textContent?.trim()) {
        node.textContent = this.tooltipText;
      }
    });
    this.button.classList.remove('ads-button--quaternary');
    this.button.classList.add('ads-button--secondary');
    this.dataset.copied = '';

    const revert = () => {
      window.clearTimeout(this.#copiedTimeout);
      this.button.innerHTML = originalHTML;
      this.button.className = originalClassName;
      delete this.dataset.copied;
      this.#copied = false;
    };

    this.#copiedTimeout = window.setTimeout(revert, COPIED_TIMEOUT_MS);
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
