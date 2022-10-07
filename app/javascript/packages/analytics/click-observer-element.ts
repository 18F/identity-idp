import { trackEvent } from '.';

class ClickObserverElement extends HTMLElement {
  trackEvent: typeof trackEvent = trackEvent;

  connectedCallback() {
    this.addEventListener('click', () => this.handleClick());
  }

  get eventName(): string | null {
    return this.getAttribute('event-name');
  }

  /**
   * Logs an event using the element's given event name.
   */
  handleClick() {
    if (this.eventName) {
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
