class PrintButtonElement extends HTMLElement {
  connectedCallback() {
    this.addEventListener('click', () => window.print());
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-print-button': PrintButtonElement;
  }
}

if (!customElements.get('lg-print-button')) {
  customElements.define('lg-print-button', PrintButtonElement);
}

export default PrintButtonElement;
