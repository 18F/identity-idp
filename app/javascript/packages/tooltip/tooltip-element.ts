class TooltipElement extends HTMLElement {
  connectedCallback() {
    this.tooltipElement.setAttribute('title', this.tooltipText);
  }

  get tooltipElement(): HTMLElement {
    return this.firstElementChild as HTMLElement;
  }

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
