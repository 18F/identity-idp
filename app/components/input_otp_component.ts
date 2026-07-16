import { bindFormSubmitters } from '@18f/identity-validated-field/form-submitters';

export type InputOtpOptions = {
  length: number;
  numeric: boolean;
  optionalPrefix?: string;
};

export type PasteSelection = {
  start: number;
  end: number;
};

type PasteResult = {
  value: string;
  selection: number;
};

const characterPattern = (numeric: boolean) => (numeric ? /[0-9]/g : /[a-zA-Z0-9]/g);

export const getCodeValue = (value: string, optionalPrefix = '') => {
  if (optionalPrefix && value.startsWith(optionalPrefix)) {
    return value.slice(optionalPrefix.length);
  }

  return value;
};

export const normalizeInputOtpValue = (
  value: string,
  { length, numeric, optionalPrefix = '' }: InputOtpOptions,
) => {
  const hasPrefix = Boolean(optionalPrefix && value.startsWith(optionalPrefix));
  const code = getCodeValue(value, hasPrefix ? optionalPrefix : '')
    .match(characterPattern(numeric))
    ?.join('')
    .slice(0, length);

  return `${hasPrefix ? optionalPrefix : ''}${code || ''}`;
};

const codeSelectionIndex = (index: number, value: string, optionalPrefix: string) => {
  const prefixLength = value.startsWith(optionalPrefix) ? optionalPrefix.length : 0;

  return Math.max(0, index - prefixLength);
};

const normalizedSelectionIndex = (value: string, index: number, options: InputOtpOptions) =>
  normalizeInputOtpValue(value.slice(0, Math.max(0, index)), options).length;

const getInputOtpPasteResult = (
  value: string,
  pastedValue: string,
  selection: PasteSelection,
  options: InputOtpOptions,
): PasteResult => {
  const { length, optionalPrefix = '' } = options;
  const normalizedValue = normalizeInputOtpValue(value, options);
  const normalizedPaste = normalizeInputOtpValue(pastedValue, options);
  const pastedCode = getCodeValue(normalizedPaste, optionalPrefix);

  if (
    Boolean(optionalPrefix && pastedValue.startsWith(optionalPrefix)) ||
    pastedCode.length >= length
  ) {
    return { value: normalizedPaste, selection: normalizedPaste.length };
  }

  const code = getCodeValue(normalizedValue, optionalPrefix);
  const start = codeSelectionIndex(
    normalizedSelectionIndex(value, selection.start, options),
    normalizedValue,
    optionalPrefix,
  );
  const end = codeSelectionIndex(
    normalizedSelectionIndex(value, selection.end, options),
    normalizedValue,
    optionalPrefix,
  );
  const prefix = normalizedValue.startsWith(optionalPrefix) ? optionalPrefix : '';
  const nextCode = `${code.slice(0, start)}${pastedCode}${code.slice(end)}`.slice(0, length);

  return {
    value: `${prefix}${nextCode}`,
    selection: prefix.length + Math.min(start + pastedCode.length, nextCode.length),
  };
};

export const mergeInputOtpPaste = (
  value: string,
  pastedValue: string,
  selection: PasteSelection,
  options: InputOtpOptions,
) => getInputOtpPasteResult(value, pastedValue, selection, options).value;

export const getInputOtpSlots = (
  value: string,
  options: InputOtpOptions & { password?: boolean },
) => {
  const code = getCodeValue(normalizeInputOtpValue(value, options), options.optionalPrefix);
  const character = options.password ? '•' : undefined;

  return Array.from({ length: options.length }, (_, index) =>
    code[index] ? character || code[index] : '',
  );
};

export const getInputOtpActiveIndex = (
  value: string,
  selectionStart: number,
  options: InputOtpOptions,
) => {
  const normalizedValue = normalizeInputOtpValue(value, options);
  const code = getCodeValue(normalizedValue, options.optionalPrefix);
  const selectedCodeIndex = codeSelectionIndex(
    selectionStart,
    normalizedValue,
    options.optionalPrefix || '',
  );

  return Math.min(Math.max(selectedCodeIndex, 0), Math.max(code.length, 0), options.length - 1);
};

export const isInputOtpComplete = (value: string, options: InputOtpOptions) =>
  getCodeValue(normalizeInputOtpValue(value, options), options.optionalPrefix).length ===
  options.length;

type WebOtpCredentialsContainer = CredentialsContainer & {
  get(
    options: CredentialRequestOptions & { otp: { transport: string[] } },
  ): Promise<{ code: string }>;
};

class AdsInputOtpElement extends HTMLElement {
  static isWebOTPSupported = 'OTPCredential' in window;

  #connectionController?: AbortController;
  #webOtpController?: AbortController;
  #connectedInput?: HTMLInputElement;

  connectedCallback() {
    this.cleanupConnection();
    const { input } = this;
    if (!input || this.slots.length !== this.options.length) {
      this.removeAttribute('data-enhanced');
      return;
    }

    this.#connectionController = new window.AbortController();
    this.#connectedInput = input;
    this.normalizeInput();
    this.sync();
    this.bindInput(input, this.#connectionController.signal);
    if (input.form) {
      bindFormSubmitters(input.form);
    }
    this.setAttribute('data-enhanced', 'true');
    this.receive(input);
  }

  disconnectedCallback() {
    this.cleanupConnection();
    this.removeAttribute('data-enhanced');
  }

  get input() {
    return this.querySelector<HTMLInputElement>('[data-ads-input-otp-input]');
  }

  get slots() {
    return Array.from(this.querySelectorAll<HTMLElement>('[data-ads-input-otp-slot]'));
  }

  get options(): InputOtpOptions {
    return {
      length: Number(this.dataset.length || 0),
      numeric: this.dataset.numeric !== 'false',
      optionalPrefix: this.dataset.optionalPrefix || '',
    };
  }

  get transport() {
    return this.dataset.transport;
  }

  bindInput(input: HTMLInputElement, signal: AbortSignal) {
    input.addEventListener(
      'input',
      () => {
        this.abortWebOtp();
        this.normalizeInput();
        this.sync();
      },
      { signal },
    );
    input.addEventListener('paste', (event) => this.handlePaste(event), { signal });
    input.addEventListener('focus', () => this.sync(), { signal });
    input.addEventListener('blur', () => this.sync(), { signal });
    input.addEventListener('click', () => this.sync(), { signal });
    input.addEventListener('keyup', () => this.sync(), { signal });
    input.addEventListener('select', () => this.sync(), { signal });
    input.form?.addEventListener('submit', () => this.abortWebOtp(), { once: true, signal });
  }

  normalizeInput() {
    const { input } = this;
    if (!input) {
      return;
    }

    const currentValue = input.value;
    const nextValue = normalizeInputOtpValue(currentValue, this.options);
    if (input.value === nextValue) {
      return;
    }

    const selectionStart = normalizedSelectionIndex(
      currentValue,
      input.selectionStart ?? currentValue.length,
      this.options,
    );
    const selectionEnd = normalizedSelectionIndex(
      currentValue,
      input.selectionEnd ?? currentValue.length,
      this.options,
    );
    const { selectionDirection } = input;
    input.value = nextValue;
    input.setSelectionRange(
      Math.min(selectionStart, nextValue.length),
      Math.min(selectionEnd, nextValue.length),
      selectionDirection || undefined,
    );
  }

  handlePaste(event: ClipboardEvent) {
    const { input } = this;
    if (!input || input.disabled || input.readOnly) {
      return;
    }

    const pastedValue = event.clipboardData?.getData('text') || '';
    if (!pastedValue) {
      return;
    }

    event.preventDefault();
    const { value, selection: nextSelection } = getInputOtpPasteResult(
      input.value,
      pastedValue,
      {
        start: input.selectionStart ?? input.value.length,
        end: input.selectionEnd ?? input.value.length,
      },
      this.options,
    );
    input.value = value;
    input.setSelectionRange(nextSelection, nextSelection);
    input.dispatchEvent(new Event('input', { bubbles: true }));
  }

  sync() {
    const { input } = this;
    if (!input) {
      return;
    }

    const slots = getInputOtpSlots(input.value, {
      ...this.options,
      password: input.type === 'password',
    });
    const activeIndex =
      document.activeElement === input
        ? getInputOtpActiveIndex(
            input.value,
            input.selectionStart ?? input.value.length,
            this.options,
          )
        : -1;
    const code = getCodeValue(
      normalizeInputOtpValue(input.value, this.options),
      this.options.optionalPrefix,
    );

    this.slots.forEach((slot, index) => {
      const isActive = index === activeIndex;
      slot.textContent = slots[index] || '';
      slot.classList.toggle('ads-input-otp__slot--active', isActive);
      slot.classList.toggle(
        'ads-input-otp__slot--caret',
        isActive && !input.readOnly && !code[index],
      );
    });
  }

  async receive(input: HTMLInputElement) {
    if (
      input.disabled ||
      input.readOnly ||
      !this.transport ||
      !AdsInputOtpElement.isWebOTPSupported
    ) {
      return;
    }

    this.abortWebOtp();
    const controller = new window.AbortController();
    const startingValue = input.value;
    this.#webOtpController = controller;

    try {
      const credential = await (navigator.credentials as WebOtpCredentialsContainer).get({
        otp: { transport: [this.transport] },
        signal: controller.signal,
      });
      if (
        controller.signal.aborted ||
        !this.isConnected ||
        this.#connectedInput !== input ||
        this.input !== input ||
        input.value !== startingValue ||
        input.disabled ||
        input.readOnly
      ) {
        return;
      }

      if (this.#webOtpController === controller) {
        this.#webOtpController = undefined;
      }
      input.value = normalizeInputOtpValue(credential.code, this.options);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    } catch {
      // WebOTP rejection is expected when the form submits, times out, or the user ignores it.
    } finally {
      if (this.#webOtpController === controller) {
        this.#webOtpController = undefined;
      }
    }
  }

  private abortWebOtp() {
    this.#webOtpController?.abort();
    this.#webOtpController = undefined;
  }

  private cleanupConnection() {
    this.#connectionController?.abort();
    this.#connectionController = undefined;
    this.abortWebOtp();
    this.#connectedInput = undefined;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-ads-input-otp': AdsInputOtpElement;
  }
}

if (!customElements.get('lg-ads-input-otp')) {
  customElements.define('lg-ads-input-otp', AdsInputOtpElement);
}

export default AdsInputOtpElement;
