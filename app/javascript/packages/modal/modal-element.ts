class ModalElement extends HTMLElement {
  connectedCallback() {
    this.addEventListener('click', this.#handleDismiss);
  }

  /**
   * Shows the modal dialog.
   */
  show() {
    if (!this.#dialog.open) {
      this.ownerDocument.body.classList.add('usa-js-modal--active');
      this.#dialog.showModal();
    }
  }

  /**
   * Hides the modal dialog.
   */
  hide() {
    this.ownerDocument.body.classList.remove('usa-js-modal--active');
    this.#dialog.close();
  }

  get #dialog(): HTMLDialogElement {
    return this.querySelector('dialog')!;
  }

  #handleDismiss = (event: MouseEvent) => {
    if (event.target instanceof HTMLButtonElement && 'dismiss' in event.target.dataset) {
      this.hide();
    }
  };
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-modal': ModalElement;
  }
}

if (!customElements.get('lg-modal')) {
  customElements.define('lg-modal', ModalElement);
}

export default ModalElement;
