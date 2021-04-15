class OneTimeCodeInput {
  static isWebOTPSupported = 'OTPCredential' in window;

  /**
   * @param {HTMLInputElement} input
   */
  constructor(input) {
    this.elements = { input };
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
    const controller = new AbortController();

    const form = this.elements.input.closest('form');
    if (form) {
      form.addEventListener('submit', () => controller.abort());
    }

    let code;
    try {
      ({ code } = await /** @type {OTPCredentialsContainer} */ (navigator.credentials).get({
        otp: { transport: [transport] },
        signal: controller.signal,
      }));
    } catch {}

    return code;
  }
}

export default OneTimeCodeInput;
