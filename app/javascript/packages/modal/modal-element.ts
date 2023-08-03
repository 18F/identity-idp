import { createFocusTrap } from 'focus-trap';
import type { FocusTrap } from 'focus-trap';

class ModalElement extends HTMLElement {
  trap: FocusTrap;

  connectedCallback() {
    this.trap = createFocusTrap(this, { escapeDeactivates: false });
    this.addEventListener('click', this.#handleDismiss);
  }

  /**
   * Shows the modal dialog.
   */
  show() {
    this.removeAttribute('hidden');
    this.classList.add('is-visible');
    this.ownerDocument.body.classList.add('usa-js-modal--active');
    this.trap.activate();
  }

  /**
   * Hides the modal dialog.
   */
  hide() {
    this.setAttribute('hidden', '');
    this.classList.remove('is-visible');
    this.ownerDocument.body.classList.remove('usa-js-modal--active');
    this.trap.deactivate();
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
