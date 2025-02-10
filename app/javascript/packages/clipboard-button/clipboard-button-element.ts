import { tooltip } from '@18f/identity-design-system';

class ClipboardButtonElement extends HTMLElement {
  button: HTMLButtonElement;

  connectedCallback() {
    this.button = this.querySelector('button')!;

    this.setUpTooltip();
    this.button.addEventListener('click', () => this.handleClick());
  }

  /**
   * Returns the text to be copied to the clipboard.
   */
  get clipboardText(): string {
    return this.getAttribute('clipboard-text')!;
  }

  /**
   * Returns the text to be shown in the confirmation tooltip.
   */
  get tooltipText(): string {
    return this.getAttribute('tooltip-text')!;
  }

  /**
   * Initializes the tooltip element.
   */
  setUpTooltip() {
    const { tooltipBody } = tooltip.setup(this.button);

    // A default USWDS tooltip will always be visible when the trigger has focus. The clipboard
    // button only shows the tooltip once activated. To ensure the tooltip content is read when
    // made visible, change its contents to a live region.
    tooltipBody.setAttribute('aria-live', 'polite');
  }

  /**
   * Handles behaviors associated with clicking the button.
   */
  handleClick() {
    this.writeToClipboard();
    this.showTooltip();
  }

  /**
   * Writes the element's clipboard text to the clipboard.
   */
  writeToClipboard() {
    navigator.clipboard.writeText(this.clipboardText);
  }

  /**
   * Displays confirmation tooltip and binds event to dismiss tooltip on next blur.
   */
  showTooltip() {
    const { trigger, body } = tooltip.getTooltipElements(this.button);
    body.textContent = this.tooltipText;
    tooltip.show(body, trigger, 'top');

    function hideTooltip() {
      body.textContent = '';
      tooltip.hide(body);
    }

    // In most browsers, clicking the button will focus it, and the tooltip should remain visible
    // until the user moves away. In Safari, clicking a button does not give it focus (by design),
    // so the tooltip sould remain visible as long as the user's cursor remains over the button.
    //
    // See: https://developer.mozilla.org/en-US/docs/Web/HTML/Element/button#clicking_and_focus
    if (document.activeElement === this.button) {
      this.button.addEventListener('blur', hideTooltip, { once: true });
    } else {
      this.button.addEventListener('mouseout', hideTooltip, { once: true });
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-clipboard-button': ClipboardButtonElement;
  }
}

if (!customElements.get('lg-clipboard-button')) {
  customElements.define('lg-clipboard-button', ClipboardButtonElement);
}

export default ClipboardButtonElement;
