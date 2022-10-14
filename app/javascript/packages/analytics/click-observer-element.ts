import { trackEvent } from '.';

type PropertyGetter = (element: Element) => any;

class ClickObserverElement extends HTMLElement {
  static CONTEXTUAL_PROPERTY_GETTERS: Record<string, PropertyGetter> = {
    '[type="checkbox"]': (element: Element) => ({
      checked: (element as HTMLInputElement).checked,
    }),
  };

  trackEvent: typeof trackEvent = trackEvent;

  connectedCallback() {
    this.addEventListener('click', () => this.handleClick());
  }

  get eventName(): string | null {
    return this.getAttribute('event-name');
  }

  get contextualProperties(): Record<string, any> {
    return Object.entries(ClickObserverElement.CONTEXTUAL_PROPERTY_GETTERS).reduce(
      (result, [selector, getProperties]) => {
        const element = this.querySelector(selector);
        if (element) {
          Object.assign(result, getProperties(element));
        }

        return result;
      },
      {} as Record<string, any>,
    );
  }

  /**
   * Logs an event using the element's given event name.
   */
  handleClick() {
    if (this.eventName) {
      this.trackEvent(this.eventName, this.contextualProperties);
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
