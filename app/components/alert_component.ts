const ALERT_DURATION_MS = 300;
const SINGLE_LINE_CLASS = 'ads-alert--single-line';

class AlertElement extends HTMLElement {
  #dismissing = false;
  #observer?: ResizeObserver;

  connectedCallback() {
    const dismiss = this.querySelector<HTMLElement>('[data-dismiss]');
    if (!dismiss) {
      return;
    }

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.dataset.open = 'true';
      });
    });

    dismiss.addEventListener('click', (event) => {
      event.stopPropagation();
      this.dismiss();
    });

    this.#syncSingleLine();

    if (typeof ResizeObserver !== 'undefined') {
      this.#observer = new ResizeObserver(() => this.#syncSingleLine());
      const alert = this.#alert();
      if (alert) {
        this.#observer.observe(alert);
      }
    }
  }

  disconnectedCallback() {
    this.#observer?.disconnect();
  }

  dismiss() {
    if (this.#dismissing) {
      return;
    }

    this.#dismissing = true;
    this.dataset.open = 'false';

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      this.remove();
      return;
    }

    let timeout = 0;

    const onTransitionEnd = (event: TransitionEvent) => {
      if (event.target === this && event.propertyName === 'grid-template-rows') {
        this.removeEventListener('transitionend', onTransitionEnd);
        window.clearTimeout(timeout);
        this.remove();
      }
    };

    this.addEventListener('transitionend', onTransitionEnd);
    timeout = window.setTimeout(() => {
      this.removeEventListener('transitionend', onTransitionEnd);
      this.remove();
    }, ALERT_DURATION_MS + 40);
  }

  #alert() {
    return this.querySelector<HTMLElement>('.ads-alert');
  }

  #syncSingleLine() {
    const alert = this.#alert();
    if (!alert?.querySelector('.ads-alert__close')) {
      return;
    }

    if (
      alert.classList.contains('ads-alert--with-action') ||
      alert.querySelector('.ads-alert__title')
    ) {
      alert.classList.remove(SINGLE_LINE_CLASS);
      return;
    }

    const text = alert.querySelector<HTMLElement>('.ads-alert__text');
    if (!text) {
      alert.classList.remove(SINGLE_LINE_CLASS);
      return;
    }

    const lineHeight = parseFloat(getComputedStyle(text).lineHeight);
    if (!Number.isFinite(lineHeight) || lineHeight <= 0) {
      return;
    }

    const isSingleLine = text.scrollHeight <= lineHeight * 1.1;
    alert.classList.toggle(SINGLE_LINE_CLASS, isSingleLine);
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-alert': AlertElement;
  }
}

if (!customElements.get('lg-alert')) {
  customElements.define('lg-alert', AlertElement);
}

export default AlertElement;
