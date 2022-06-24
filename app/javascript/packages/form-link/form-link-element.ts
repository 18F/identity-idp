import { once } from '@18f/identity-decorators';

class FormLinkElement extends HTMLElement {
  connectedCallback() {
    this.link.addEventListener('click', this.submit);
  }

  @once()
  get form(): HTMLFormElement {
    return this.querySelector('form')!;
  }

  @once()
  get link(): HTMLAnchorElement {
    return this.querySelector('a')!;
  }

  submit = (event: MouseEvent) => {
    event.preventDefault();
    this.form.submit();
  };
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-form-link': FormLinkElement;
  }
}

if (!customElements.get('lg-form-link')) {
  customElements.define('lg-form-link', FormLinkElement);
}

export default FormLinkElement;
