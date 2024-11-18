import { isValidNumberForRegion, isValidNumber } from 'libphonenumber-js';
import intlTelInput from 'intl-tel-input/intlTelInputWithUtils';
import type { CountryCode } from 'libphonenumber-js';
import type { Iti } from 'intl-tel-input';
import { replaceVariables } from '@18f/identity-i18n';
import { trackEvent } from '@18f/identity-analytics';

interface PhoneInputStrings {
  country_code_label: string;

  invalid_phone_us: string;

  invalid_phone_international: string;

  unsupported_country: string;
}

const updateInternationalCodeInPhone = (phone, newCode) =>
  phone.replace(new RegExp(`^\\+?(\\d+\\s+|${newCode})?`), `+${newCode} `);

export class PhoneInputElement extends HTMLElement {
  #strings: PhoneInputStrings;

  deliveryMethods: string[] = [];

  countryCodePairs: Record<string, any> = {};

  textInput: HTMLInputElement;

  codeInput: HTMLSelectElement;

  codeWrapper: Element | null;

  iti: Iti;

  connectedCallback() {
    const textInput = this.querySelector<HTMLInputElement>('.phone-input__number');
    const codeInput = this.querySelector<HTMLSelectElement>('.phone-input__international-code');
    this.codeWrapper = this.querySelector('.phone-input__international-code-wrapper');

    try {
      this.deliveryMethods = JSON.parse(this.dataset.deliveryMethods || '');
      this.countryCodePairs = JSON.parse(this.dataset.translatedCountryCodeNames || '');
    } catch {}

    if (!textInput || !codeInput) {
      return;
    }

    this.textInput = textInput;
    this.codeInput = codeInput;
    this.initializeIntlTelInput();

    this.textInput.addEventListener('countrychange', () => this.syncCountryToCodeInput());
    this.textInput.addEventListener('countrychange', () => this.trackCountryChangeEvent());
    this.textInput.addEventListener('input', () => this.validate());
    this.codeInput.addEventListener('change', () => this.formatTextInput());
    this.codeInput.addEventListener('change', () => this.validate());

    this.validate();
  }

  get selectedOption() {
    const { codeInput } = this;

    return codeInput && codeInput.options[codeInput.selectedIndex];
  }

  get supportedCountryCodes(): string[] | undefined {
    const { codeInput } = this;

    if (codeInput && codeInput.dataset.countries) {
      try {
        return JSON.parse(codeInput.dataset.countries);
      } catch {}
    }

    return undefined;
  }

  get strings(): PhoneInputStrings {
    if (!this.#strings) {
      this.#strings = JSON.parse(this.querySelector('.phone-input__strings')?.textContent || '');
    }

    return this.#strings;
  }

  get selectedCountry(): HTMLElement {
    return this.querySelector('.iti__selected-country')!;
  }

  get countryList(): HTMLUListElement | null {
    return this.querySelector('.iti__country-list')!;
  }

  /**
   * Logs an event when the country code has been changed.
   */
  trackCountryChangeEvent() {
    const countryCode = this.getSelectedCountryCode();
    if (countryCode) {
      trackEvent('phone_input_country_changed', { country_code: countryCode });
    }
  }

  /**
   * Mirrors country change to the hidden select field, which holds the value for form submission.
   */
  syncCountryToCodeInput({ fireChangeEvent = true }: { fireChangeEvent?: boolean } = {}) {
    const countryCode = this.getSelectedCountryCode();
    if (countryCode) {
      this.codeInput.value = countryCode;
      this.selectedCountry.removeAttribute('title');
      if (fireChangeEvent) {
        this.codeInput.dispatchEvent(new CustomEvent('change', { bubbles: true }));
      }
    }
  }

  initializeIntlTelInput() {
    const { supportedCountryCodes, countryCodePairs } = this;

    const iti = intlTelInput(this.textInput, {
      countryOrder: ['US', 'CA'],
      initialCountry: this.codeInput.value,
      i18n: {
        ...countryCodePairs,
        selectedCountryAriaLabel: this.strings.country_code_label,
      },
      onlyCountries: supportedCountryCodes,
      autoPlaceholder: 'off',
      formatAsYouType: false,
      useFullscreenPopup: false,
    });

    this.iti = iti;

    // Improve base accessibility of intl-tel-input
    this.selectedCountry.setAttribute('aria-haspopup', 'listbox');

    this.syncCountryToCodeInput({ fireChangeEvent: false });

    return iti;
  }

  validate() {
    const { textInput, codeInput, selectedOption } = this;
    if (!textInput || !codeInput || !selectedOption) {
      return;
    }

    const phoneNumber = textInput.value;
    const countryCode = codeInput.value as CountryCode;

    textInput.setCustomValidity('');
    if (!phoneNumber) {
      return;
    }

    const isInvalidCountry = !isValidNumberForRegion(phoneNumber, countryCode);
    if (isInvalidCountry) {
      textInput.setCustomValidity(this.getInvalidFormatMessage(countryCode));
    }

    const isInvalidPhoneNumber = !isValidNumber(phoneNumber, countryCode);
    if (isInvalidPhoneNumber) {
      textInput.setCustomValidity(this.getInvalidFormatMessage(countryCode));
    }

    if (!this.isSupportedCountry()) {
      const validationMessage = replaceVariables(this.strings.unsupported_country || '', {
        location: selectedOption.dataset.countryName,
      });

      textInput.setCustomValidity(validationMessage);

      // While most other validations can wait 'til submission to present user feedback, this one
      // should notify immediately.
      textInput.dispatchEvent(new CustomEvent('invalid'));
    }
  }

  getInvalidFormatMessage(countryCode: CountryCode): string {
    return countryCode === 'US' ? this.strings.invalid_phone_us || '' : this.strings.invalid_phone_international || '';
  }

  formatTextInput() {
    const { textInput, selectedOption } = this;
    if (!textInput || !selectedOption) {
      return;
    }

    const phone = textInput.value;
    const selectedInternationalCode = selectedOption.dataset.countryCode;
    textInput.value = updateInternationalCodeInPhone(phone, selectedInternationalCode);
    textInput.dispatchEvent(new CustomEvent('input', { bubbles: true }));
  }

  /**
   * Returns true if the delivery option is valid for the selected option, or false otherwise.
   */
  isDeliveryOptionSupported(delivery: string): boolean {
    const { selectedOption } = this;

    return !!selectedOption && selectedOption.getAttribute(`data-supports-${delivery}`) !== 'false';
  }

  /**
   * Returns true if the currently selected country can receive a supported delivery options, or
   * false otherwise.
   *
   * @return Whether selected country is supported.
   */
  isSupportedCountry(): boolean {
    return this.deliveryMethods.some((delivery) => this.isDeliveryOptionSupported(delivery));
  }

  getSelectedCountryCode(): string | undefined {
    return (this.iti.getSelectedCountryData().iso2 as string | undefined)?.toUpperCase();
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-phone-input': PhoneInputElement;
  }
}

if (!customElements.get('lg-phone-input')) {
  customElements.define('lg-phone-input', PhoneInputElement);
}
