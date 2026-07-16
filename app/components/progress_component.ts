// Match chrome: width < 768px  ⇒  max-width: 767px
const MOBILE_QUERY = '(max-width: 767px)';

/**
 * Centers the current step once, and makes the scroller keyboard-focusable
 * when content overflows (scrollable-region-focusable).
 */
class ProgressElement extends HTMLElement {
  #scroller?: HTMLElement;
  #stepper?: HTMLElement;
  #mediaQuery = window.matchMedia(MOBILE_QUERY);
  #resizeObserver?: ResizeObserver;

  connectedCallback() {
    this.#scroller = this.querySelector<HTMLElement>('.ads-progress__scroll') ?? undefined;
    this.#stepper = this.querySelector<HTMLElement>('.ads-progress__stepper') ?? undefined;
    if (!this.#scroller) {
      return;
    }

    window.requestAnimationFrame(() => {
      this.#centerCurrentStep();
      this.#syncScrollerFocusable();
    });

    this.#mediaQuery.addEventListener('change', this.#onLayoutChange);

    if (typeof ResizeObserver !== 'undefined') {
      this.#resizeObserver = new ResizeObserver(() => this.#syncScrollerFocusable());
      this.#resizeObserver.observe(this.#scroller);
    }
  }

  disconnectedCallback() {
    this.#mediaQuery.removeEventListener('change', this.#onLayoutChange);
    this.#resizeObserver?.disconnect();
  }

  #onLayoutChange = () => {
    this.#centerCurrentStep();
    this.#syncScrollerFocusable();
  };

  #centerCurrentStep() {
    const active = this.querySelector<HTMLElement>('[aria-current="step"]');
    active?.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'auto' });
  }

  #syncScrollerFocusable() {
    const scroller = this.#scroller;
    if (!scroller) {
      return;
    }

    const overflows = scroller.scrollWidth > scroller.clientWidth + 1;
    if (overflows) {
      scroller.tabIndex = 0;
      // Label the focusable scroller only; drop list label to avoid dual announcement.
      const label =
        this.#stepper?.getAttribute('aria-label') ||
        scroller.getAttribute('aria-label') ||
        'Step progress';
      scroller.setAttribute('aria-label', label);
      this.#stepper?.removeAttribute('aria-label');
    } else {
      if (document.activeElement === scroller) {
        scroller.blur();
      }
      scroller.removeAttribute('tabindex');
      scroller.removeAttribute('aria-label');
      // Restore list label when scroller is not a tab stop.
      if (this.#stepper && !this.#stepper.getAttribute('aria-label')) {
        this.#stepper.setAttribute(
          'aria-label',
          this.getAttribute('data-progress-label') || 'Step progress',
        );
      }
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'ads-progress': ProgressElement;
  }
}

if (!customElements.get('ads-progress')) {
  customElements.define('ads-progress', ProgressElement);
}

export default ProgressElement;
