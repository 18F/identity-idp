import { tooltip } from '@18f/identity-design-system';

class BadgeTooltipElement extends HTMLElement {
  badge: HTMLElement;

  connectedCallback() {
    this.badge = this.querySelector('.usa-tooltip')!;

    this.setUpTooltip();
    this.badge.addEventListener('mouseover', () => this.handleHover());
    document.addEventListener('keyup', (event) => this.#handleKeyDown(event));
  }

  /**
   * Retrieves the text to be shown in the tooltip.
   */
  get tooltipText(): string {
    return this.getAttribute('tooltip-text')!;
  }

  /**
   * Initializes the tooltip element.
   */
  setUpTooltip() {
    const { tooltipBody } = tooltip.setup(this.badge);

    // A default USWDS tooltip will always be visible when the badge is hovered over.
    // To ensure the tooltip content is read when made visible,
    // change its contents to a live region.
    tooltipBody.setAttribute('aria-live', 'polite');
  }

  /**
   * Handles the badge mouseover.
   */
  handleHover() {
    this.showTooltip();
  }

  #handleKeyDown(event: KeyboardEvent) {
    switch (event.key) {
      case 'Tab':
        if (document.activeElement === this.badge) {
          this.showTooltip();
        }
        break;

      default:
    }
  }

  /**
   * Displays confirmation tooltip and binds event to dismiss tooltip on mouseout.
   */
  showTooltip() {
    const { trigger, body } = tooltip.getTooltipElements(this.badge);
    body.textContent = this.tooltipText;
    tooltip.show(body, trigger, 'top');

    function hideTooltip() {
      body.textContent = '';
      tooltip.hide(body);
    }
    this.badge.addEventListener('mouseout', hideTooltip, { once: true });

    if (document.activeElement === this.badge) {
      this.badge.addEventListener('blur', hideTooltip, { once: true });
    } else {
      this.badge.addEventListener('mouseout', hideTooltip, { once: true });
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-badge-tooltip': BadgeTooltipElement;
  }
}

if (!customElements.get('lg-badge-tooltip')) {
  customElements.define('lg-badge-tooltip', BadgeTooltipElement);
}

export default BadgeTooltipElement;
