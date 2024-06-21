import { tooltip } from '@18f/identity-design-system';

class BadgeTooltipElement extends HTMLElement {
  badge: HTMLElement;

  connectedCallback() {
    this.badge = this.querySelector('.usa-tooltip')!;

    this.setUpTooltip();
    this.badge.addEventListener('mouseover', () => this.handleHover());
    this.badge.addEventListener('focus', () => this.#handleFocus());
  }

  /**
   * Retrieves the text to be shown in the tooltip.
   */
  get tooltipText(): string {
    return this.getAttribute('data-tooltip-text')!;
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

  #handleFocus() {
    this.showTooltip();
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
    this.badge.addEventListener('blur', hideTooltip, { once: true });
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
