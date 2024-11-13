class SubmitButtonElement extends HTMLElement {
  connectedCallback() {
    this.button.addEventListener('click', this.#preventDefaultIfSubmitting);
    this.form?.addEventListener('submit', this.#activate);
  }

  get form(): HTMLFormElement | null {
    return this.closest('form');
  }

  get button(): HTMLButtonElement {
    return this.querySelector('button')!;
  }

  get isSubmitting(): boolean {
    return this.button.getAttribute('aria-disabled') === 'true';
  }

  #activate = () => {
    this.button.classList.add('usa-button--active');
    this.button.setAttribute('aria-disabled', 'true');
  };

  #preventDefaultIfSubmitting = (event: MouseEvent) => {
    if (this.isSubmitting) {
      event.preventDefault();
    }
  };
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
