import { isValidNumberForRegion, isValidNumber } from 'libphonenumber-js';
import 'intl-tel-input/build/js/utils.js';
import intlTelInput from 'intl-tel-input';
import type { CountryCode } from 'libphonenumber-js';
import type { Plugin as IntlTelInputPlugin, Options } from 'intl-tel-input';
import { replaceVariables } from '@18f/identity-i18n';
import { CAPTCHA_EVENT_NAME } from '@18f/identity-captcha-submit-button/captcha-submit-button-element';
import { trackEvent } from '@18f/identity-analytics';

interface PhoneInputStrings {
  country_code_label: string;

  invalid_phone_us: string;

  invalid_phone_international: string;

  unsupported_country: string;
}

interface IntlTelInput extends IntlTelInputPlugin {
  flagsContainer: HTMLElement;

  selectedFlag: HTMLElement;

  options: Options;
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

  iti: IntlTelInput;

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
    this.ownerDocument.addEventListener(CAPTCHA_EVENT_NAME, this.handleCaptchaChallenge);

    this.validate();
  }

  disconnectedCallback() {
    this.ownerDocument.removeEventListener(CAPTCHA_EVENT_NAME, this.handleCaptchaChallenge);
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

  /**
   * Returns the element which represents the flag dropdown's currently selected value, which is
   * rendered as a text element within the combobox. As defined by the ARIA specification, a
   * combobox's value is determined by its contents if it is not an input element.
   *
   * @see https://w3c.github.io/aria/#combobox
   */
  get valueText(): HTMLElement {
    return this.iti.selectedFlag.querySelector('.usa-sr-only')!;
  }

  get hasDropdown(): boolean {
    return Boolean(this.supportedCountryCodes && this.supportedCountryCodes.length > 1);
  }

  get captchaExemptCountries(): string[] | boolean {
    try {
      return JSON.parse(this.dataset.captchaExemptCountries!);
    } catch {
      return true;
    }
  }

  /**
   * Logs an event when the country code has been changed.
   */
  trackCountryChangeEvent() {
    const { iso2 } = this.iti.getSelectedCountryData();
    trackEvent('phone_input_country_changed', { country_code: iso2.toUpperCase() });
  }

  /**
   * Mirrors country change to the hidden select field, which holds the value for form submission.
   */
  syncCountryToCodeInput({ fireChangeEvent = true }: { fireChangeEvent?: boolean } = {}) {
    const country = this.iti.getSelectedCountryData();
    if (country.iso2 && this.codeInput) {
      this.codeInput.value = country.iso2.toUpperCase();
      if (this.hasDropdown) {
        // Move value text from title attribute to the flag's hidden text element.
        // See: https://github.com/jackocnr/intl-tel-input/blob/d54b127/src/js/intlTelInput.js#L1191-L1197
        this.valueText.textContent = this.iti.selectedFlag.title;
        this.iti.selectedFlag.removeAttribute('title');
      }
      if (fireChangeEvent) {
        this.codeInput.dispatchEvent(new CustomEvent('change', { bubbles: true }));
      }
    }
  }

  initializeIntlTelInput() {
    const { supportedCountryCodes, countryCodePairs } = this;

    const iti = intlTelInput(this.textInput, {
      preferredCountries: ['US', 'CA'],
      initialCountry: this.codeInput.value,
      localizedCountries: countryCodePairs,
      onlyCountries: supportedCountryCodes,
      autoPlaceholder: 'off',
      allowDropdown: this.hasDropdown,
    }) as IntlTelInput;

    this.iti = iti;

    if (this.hasDropdown) {
      // Remove duplicate items in the country list
      const preferred: NodeListOf<HTMLLIElement> =
        iti.countryList.querySelectorAll('.iti__preferred');
      preferred.forEach((listItem) => {
        const { countryCode } = listItem.dataset;
        const duplicates: NodeListOf<HTMLLIElement> = iti.countryList.querySelectorAll(
          `.iti__standard[data-country-code="${countryCode}"]`,
        );
        duplicates.forEach((duplicateListItem) => {
          duplicateListItem.parentNode?.removeChild(duplicateListItem);
        });
      });

      // Improve base accessibility of intl-tel-input
      const valueText = document.createElement('div');
      valueText.classList.add('usa-sr-only');
      iti.selectedFlag.appendChild(valueText);
      iti.selectedFlag.setAttribute('aria-label', this.strings.country_code_label);
      iti.selectedFlag.removeAttribute('aria-owns');
    }

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
    return countryCode === 'US'
      ? this.strings.invalid_phone_us || ''
      : this.strings.invalid_phone_international || '';
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

  handleCaptchaChallenge = (event: Event) => {
    const { iso2 = 'us' } = this.iti.getSelectedCountryData();
    const isExempt =
      typeof this.captchaExemptCountries === 'boolean'
        ? this.captchaExemptCountries
        : this.captchaExemptCountries.includes(iso2.toUpperCase());

    if (isExempt) {
      event.preventDefault();
    }
  };
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-phone-input': PhoneInputElement;
  }
}

if (!customElements.get('lg-phone-input')) {
  customElements.define('lg-phone-input', PhoneInputElement);
}
