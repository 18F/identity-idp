class OneTimeCodeInput {
  static isWebOTPSupported = 'OTPCredential' in window;

  /**
   * @param {HTMLInputElement} input
   */
  constructor(input) {
    this.elements = { input, form: input.closest('form') };
    this.options = {
      transport: /** @type {OTPCredentialTransportType=} */ (input.dataset.transport),
    };
  }

  bind() {
    this.createHiddenInput();
    if (OneTimeCodeInput.isWebOTPSupported && this.options.transport) {
      this.receive(this.options.transport);
    }
  }

  createHiddenInput() {
    const { input } = this.elements;
    const hiddenInput = /** @type {HTMLInputElement} */ (document.createElement('input'));
    hiddenInput.name = input.name;
    hiddenInput.value = input.value;
    hiddenInput.type = 'hidden';
    this.elements.hiddenInput = hiddenInput;
    /** @type {HTMLElement} */ (input.parentNode).insertBefore(hiddenInput, input);
    input.removeAttribute('name');
    input.addEventListener('input', () => {
      hiddenInput.value = input.value;
    });
  }

  /**
   * @param {OTPCredentialTransportType} transport
   */
  async receive(transport) {
    const { input, form } = this.elements;
    const controller = new window.AbortController();

    if (form) {
      form.addEventListener('submit', () => controller.abort());
    }

    try {
      const { code } = await /** @type {OTPCredentialsContainer} */ (navigator.credentials).get({
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

export default OneTimeCodeInput;
