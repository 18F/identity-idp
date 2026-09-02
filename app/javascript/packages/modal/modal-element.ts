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
      if (this.#isNdsModal) {
        // NDS `.modal` CSS gates its visible/animated open state on
        // `[open].is-open` (body scroll-lock on `.modal--active`). Legacy
        // USWDS modal CSS has zero `.is-open`/`.modal--active` refs, and the
        // legacy dialog is `.modal__content` (not `.modal`), so this branch
        // never runs for legacy modals — their behavior is unchanged.
        this.ownerDocument.body.classList.add('modal--active');
        this.#dialog.classList.remove('is-closing');
        this.#dialog.classList.add('is-open');
      }
    }
  }

  /**
   * Hides the modal dialog.
   */
  hide() {
    this.ownerDocument.body.classList.remove('usa-js-modal--active');
    this.ownerDocument.body.classList.remove('modal--active');

    const dialog = this.#dialog;
    if (dialog.classList.contains('is-open')) {
      // Play the nds close animation, then finalize on animationend. A
      // timeout fallback guarantees the dialog closes even when no animation
      // fires (prefers-reduced-motion, jsdom, or missing keyframes).
      dialog.classList.remove('is-open');
      dialog.classList.add('is-closing');

      let settled = false;
      let fallback: ReturnType<typeof setTimeout>;
      const finalize = () => {
        if (settled) {
          return;
        }
        settled = true;
        clearTimeout(fallback);
        dialog.removeEventListener('animationend', finalize);
        dialog.classList.remove('is-closing');
        if (dialog.open) {
          dialog.close();
        }
      };

      fallback = setTimeout(finalize, this.#closeAnimationFallbackMs);
      dialog.addEventListener('animationend', finalize);
    } else if (dialog.open) {
      dialog.close();
    }
  }

  // Upper bound on the nds close animation; kept in sync with the .modal
  // is-closing keyframe duration.
  #closeAnimationFallbackMs = 400;

  get #isNdsModal(): boolean {
    return this.#dialog.classList.contains('modal');
  }

  get #dialog(): HTMLDialogElement {
    return this.querySelector('dialog')!;
  }

  #handleDismiss = (event: MouseEvent) => {
    if (
      event.target instanceof HTMLElement &&
      (event.target.closest('[data-dismiss]') || event.target.closest('[data-nds-modal-close]'))
    ) {
      this.hide();
    }
  };
}

/**
 * Document-level open-trigger handler. A trigger carrying `data-nds-modal-open`
 * and `aria-controls="<dialog-id>"` opens the owning `lg-modal` by resolving the
 * referenced dialog and calling its existing `show()`. Registered once for the
 * document; works whether the trigger lives inside its `lg-modal` (ModalComponent)
 * or outside it (e.g. the official-banner "how" button). Legacy modals expose the
 * same `show()`, so this trigger is bucket-agnostic.
 */
const handleOpenTrigger = (event: MouseEvent) => {
  const { target } = event;
  if (!(target instanceof Element)) {
    return;
  }

  const trigger = target.closest('[data-nds-modal-open]');
  if (!trigger) {
    return;
  }

  const dialogId = trigger.getAttribute('aria-controls');
  const dialog = dialogId ? trigger.ownerDocument.getElementById(dialogId) : null;
  const modal = dialog?.closest('lg-modal');
  if (!(modal instanceof ModalElement)) {
    return;
  }

  event.preventDefault();
  trigger.setAttribute('aria-expanded', 'true');
  modal.show();
};

declare global {
  interface HTMLElementTagNameMap {
    'lg-modal': ModalElement;
  }
}

if (!customElements.get('lg-modal')) {
  customElements.define('lg-modal', ModalElement);
  document.addEventListener('click', handleOpenTrigger);
}

export default ModalElement;
