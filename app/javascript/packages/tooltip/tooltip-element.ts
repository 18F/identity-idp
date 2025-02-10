import { tooltip } from '@18f/identity-design-system';

class TooltipElement extends HTMLElement {
  connectedCallback() {
    this.tooltipElement.setAttribute('title', this.tooltipText);
    this.tooltipElement.classList.add('usa-tooltip');
    tooltip.on(this.tooltipElement);
  }

  get tooltipElement(): HTMLElement {
    return this.firstElementChild as HTMLElement;
  }

  /**
   * Retrieves the text to be shown in the tooltip.
   */
  get tooltipText(): string {
    return this.getAttribute('tooltip-text')!;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-tooltip': TooltipElement;
  }
}

if (!customElements.get('lg-tooltip')) {
  customElements.define('lg-tooltip', TooltipElement);
}

export default TooltipElement;
