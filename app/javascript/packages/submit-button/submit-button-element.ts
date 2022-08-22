class SubmitButtonElement extends HTMLElement {
  connectedCallback() {
    this.form?.addEventListener('submit', () => this.activate());
  }

  get form(): HTMLFormElement | null {
    return this.closest('form');
  }

  get button(): HTMLButtonElement {
    return this.querySelector('button')!;
  }

  activate() {
    this.button.classList.add('usa-button--active');
    this.button.disabled = true;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-submit-button': SubmitButtonElement;
  }
}

if (!customElements.get('lg-submit-button')) {
  customElements.define('lg-submit-button', SubmitButtonElement);
}

export default SubmitButtonElement;
