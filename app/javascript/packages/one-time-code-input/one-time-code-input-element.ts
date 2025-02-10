class OneTimeCodeInputElement extends HTMLElement {
  static isWebOTPSupported = 'OTPCredential' in window;

  connectedCallback() {
    this.createHiddenInput();

    if (OneTimeCodeInputElement.isWebOTPSupported && this.transport) {
      this.receive(this.transport);
    }
  }

  get input(): HTMLInputElement {
    return this.querySelector<HTMLInputElement>('.one-time-code-input__input')!;
  }

  get form(): HTMLFormElement | null {
    return this.input.closest('form');
  }

  get transport(): OTPCredentialTransportType {
    return this.getAttribute('transport') as OTPCredentialTransportType;
  }

  createHiddenInput() {
    const { input } = this;

    const hiddenInput = document.createElement('input');
    const label = input.ownerDocument.querySelector(`label[for="${input.id}"]`);
    const modifiedId = `${input.id}-${Math.floor(Math.random() * 1000000)}`;
    hiddenInput.name = input.name;
    hiddenInput.value = input.value;
    hiddenInput.type = 'hidden';
    input.parentNode?.insertBefore(hiddenInput, input);
    input.removeAttribute('name');
    input.setAttribute('id', modifiedId);
    label?.setAttribute('for', modifiedId);
    input.addEventListener('input', () => {
      hiddenInput.value = input.value;
    });
  }

  async receive(transport: OTPCredentialTransportType) {
    const { input, form } = this;
    const controller = new window.AbortController();

    if (form) {
      form.addEventListener('submit', () => controller.abort());
    }

    try {
      const { code } = await (navigator.credentials as OTPCredentialsContainer).get({
        otp: { transport: [transport] },
        signal: controller.signal,
      });

      input.value = code;
      input.dispatchEvent(new CustomEvent('input', { bubbles: true }));
    } catch {
      // Thrown errors may be expected if:
      // - the user submits the form and triggers the abort controller's signal. ('AbortError')
      // - or, credential retrieval times out. ('InvalidStateError')
      // Timeout errors occur in the real world, but they are not defined in the current version of
      // of the specification. Ideally we would only allow expected errors and throw any others, but
      // since this could unknowingly change in the future, we instead absorb all errors.
    }
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-one-time-code-input': OneTimeCodeInputElement;
  }
}

if (!customElements.get('lg-one-time-code-input')) {
  customElements.define('lg-one-time-code-input', OneTimeCodeInputElement);
}

export default OneTimeCodeInputElement;
