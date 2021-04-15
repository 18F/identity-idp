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
    if (OneTimeCodeInput.isWebOTPSupported && this.options.transport) {
      this.receive(this.options.transport);
    }
  }

  /**
   * @param {OTPCredentialTransportType} transport
   */
  async receive(transport) {
    const { input, form } = this.elements;
    const controller = new AbortController();

    if (form) {
      form.addEventListener('submit', () => controller.abort());
    }

    try {
      const { code } = await /** @type {OTPCredentialsContainer} */ (navigator.credentials).get({
        otp: { transport: [transport] },
        signal: controller.signal,
      });

      input.value = code;
      form?.submit();
    } catch {}
  }
}

export default OneTimeCodeInput;
