import { trackEvent } from '.';

class ClickObserverElement extends HTMLElement {
  trackEvent: typeof trackEvent = trackEvent;

  connectedCallback() {
    this.addEventListener('click', (event) => this.handleEvent(event), true);
    this.addEventListener('change', (event) => this.handleEvent(event), true);
  }

  get eventName(): string | null {
    return this.getAttribute('event-name');
  }

  /**
   * Whether event handling should handle target as a checkbox.
   */
  get isHandledAsCheckbox(): boolean {
    return !!this.querySelector('[type=checkbox]');
  }

  handleEvent(event: Event) {
    if (!this.eventName) {
      return;
    }

    if (event.type === 'change' && this.isHandledAsCheckbox) {
      this.trackEvent(this.eventName, { checked: (event.target as HTMLInputElement).checked });
    } else if (event.type === 'click' && !this.isHandledAsCheckbox) {
      this.trackEvent(this.eventName);
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-click-observer': ClickObserverElement;
  }
}

if (!customElements.get('lg-click-observer')) {
  customElements.define('lg-click-observer', ClickObserverElement);
}

export default ClickObserverElement;
