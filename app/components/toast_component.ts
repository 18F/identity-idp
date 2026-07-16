const DEFAULT_SHOW_DELAY_MS = 500;
const DEFAULT_DISMISS_AFTER_MS = 3000;
const TOAST_DURATION_MS = 300;

class ToastElement extends HTMLElement {
  #dismissing = false;

  #showTimer?: number;

  #autoDismissTimer?: number;

  #removeTimer?: number;

  connectedCallback() {
    // Escape page stacking / fixed containing blocks (view-transition main, sticky chrome).
    if (this.parentElement !== document.body) {
      document.body.append(this);
      return;
    }

    this.addEventListener('click', this.#onClick);

    const showDelay = this.#numberDataset('showDelay', DEFAULT_SHOW_DELAY_MS);

    this.#showTimer = window.setTimeout(() => {
      requestAnimationFrame(() => {
        this.dataset.open = 'true';
        const announcement = this.querySelector('[data-ads-toast-announcement]');
        announcement?.setAttribute('role', 'status');
        announcement?.setAttribute('aria-live', 'polite');
        this.#scheduleAutoDismiss();
      });
    }, showDelay);
  }

  disconnectedCallback() {
    this.removeEventListener('click', this.#onClick);
    this.#clearTimers();
  }

  dismiss() {
    if (this.#dismissing) {
      return;
    }

    this.#dismissing = true;
    this.#clearTimers();
    this.dataset.open = 'false';

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      this.remove();
      return;
    }

    let onTransitionEnd: (event: TransitionEvent) => void;
    const remove = () => {
      this.removeEventListener('transitionend', onTransitionEnd);
      window.clearTimeout(this.#removeTimer);
      this.remove();
    };
    onTransitionEnd = (event: TransitionEvent) => {
      if (
        event.target === this &&
        (event.propertyName === 'opacity' || event.propertyName === 'transform')
      ) {
        remove();
      }
    };

    this.addEventListener('transitionend', onTransitionEnd);
    this.#removeTimer = window.setTimeout(remove, TOAST_DURATION_MS + 40);
  }

  #onClick = () => {
    this.dismiss();
  };

  #scheduleAutoDismiss() {
    const dismissAfter = this.#numberDataset('dismissAfter', DEFAULT_DISMISS_AFTER_MS);
    if (dismissAfter <= 0) {
      return;
    }

    this.#autoDismissTimer = window.setTimeout(() => this.dismiss(), dismissAfter);
  }

  #numberDataset(key: 'showDelay' | 'dismissAfter', fallback: number) {
    const value = Number(this.dataset[key]);
    return Number.isFinite(value) ? value : fallback;
  }

  #clearTimers() {
    window.clearTimeout(this.#showTimer);
    window.clearTimeout(this.#autoDismissTimer);
    window.clearTimeout(this.#removeTimer);
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-toast': ToastElement;
  }
}

if (!customElements.get('lg-toast')) {
  customElements.define('lg-toast', ToastElement);
}

export default ToastElement;
