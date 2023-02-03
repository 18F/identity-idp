import { isValidNumber, isValidNumberForRegion } from 'libphonenumber-js';
import 'intl-tel-input/build/js/utils.js';
import intlTelInput from 'intl-tel-input';
import type { CountryCode } from 'libphonenumber-js';
import type { Plugin as IntlTelInputPlugin, IntlTelInputGlobals, Options } from 'intl-tel-input';
import { replaceVariables } from '@18f/identity-i18n';
import type CaptchaSubmitButtonElement from '@18f/identity-captcha-submit-button/captcha-submit-button-element';

interface PhoneInputStrings {
  country_code_label: string;

  invalid_phone: string;

  unsupported_country: string;
}

interface IntlTelInput extends IntlTelInputPlugin {
  flagsContainer: HTMLElement;

  selectedFlag: HTMLElement;

  options: Options;
}

const { intlTelInputUtils } = window as typeof window & IntlTelInputGlobals;

const isPhoneValid = (phone, countryCode) => {
  let phoneValid = isValidNumber(phone, countryCode);
  if (!phoneValid && countryCode === 'US') {
    phoneValid = isValidNumber(`+1 ${phone}`, countryCode);
  }
  return phoneValid;
};

const updateInternationalCodeInPhone = (phone, newCode) =>
  phone.replace(new RegExp(`^\\+?(\\d+\\s+|${newCode})?`), `+${newCode} `);

export class PhoneInputElement extends HTMLElement {
  #strings: PhoneInputStrings;

  deliveryMethods: string[] = [];

  countryCodePairs: Record<string, any> = {};

  textInput: HTMLInputElement;

  codeInput: HTMLSelectElement;

  codeWrapper: Element | null;

  exampleText: Element | null;

  iti: IntlTelInput;

  connectedCallback() {
    const textInput = this.querySelector<HTMLInputElement>('.phone-input__number');
    const codeInput = this.querySelector<HTMLSelectElement>('.phone-input__international-code');
    this.codeWrapper = this.querySelector('.phone-input__international-code-wrapper');
    this.exampleText = this.querySelector('.phone-input__example');

    try {
      this.deliveryMethods = JSON.parse(this.dataset.deliveryMethods || '');
      this.countryCodePairs = JSON.parse(this.dataset.translatedCountryCodeNames || '');
    } catch {}

    if (!textInput || !codeInput) {
      return;
    }

    this.textInput = textInput;
    this.codeInput = codeInput;
    this.iti = this.initializeIntlTelInput();

    this.textInput.addEventListener('countrychange', () => this.syncCountryChangeToCodeInput());
    this.textInput.addEventListener('input', () => this.validate());
    this.codeInput.addEventListener('change', () => this.formatTextInput());
    this.codeInput.addEventListener('change', () => this.setExampleNumber());
    this.codeInput.addEventListener('change', () => this.validate());
    this.codeInput.addEventListener('change', () => this.setCaptchaButtonExemption());

    this.setExampleNumber();
    this.validate();
    this.setCaptchaButtonExemption();
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

  get captchaSubmitButton(): CaptchaSubmitButtonElement | null {
    return this.closest('form')?.querySelector('lg-captcha-submit-button') || null;
  }

  get captchaExemptCountries(): string[] | boolean {
    try {
      return JSON.parse(this.dataset.captchaExemptCountries!);
    } catch {
      return true;
    }
  }

  /**
   * Mirrors country change to the hidden select field, which holds the value for form submission.
   */
  syncCountryChangeToCodeInput() {
    const country = this.iti.getSelectedCountryData();
    if (country.iso2 && this.codeInput) {
      this.codeInput.value = country.iso2.toUpperCase();
      this.codeInput.dispatchEvent(new CustomEvent('change', { bubbles: true }));
    }
  }

  initializeIntlTelInput() {
    const { supportedCountryCodes, countryCodePairs } = this;
    const allowDropdown = supportedCountryCodes && supportedCountryCodes.length > 1;

    const iti = intlTelInput(this.textInput, {
      preferredCountries: ['US', 'CA'],
      localizedCountries: countryCodePairs,
      onlyCountries: supportedCountryCodes,
      autoPlaceholder: 'off',
      allowDropdown,
    }) as IntlTelInput;

    if (allowDropdown) {
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
      iti.flagsContainer.setAttribute('aria-label', this.strings.country_code_label);
      iti.selectedFlag.setAttribute('aria-haspopup', 'true');
      iti.selectedFlag.setAttribute('role', 'button');
      iti.selectedFlag.removeAttribute('aria-owns');
    }

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
      textInput.setCustomValidity(this.strings.invalid_phone || '');
    }

    const isInvalidPhoneNumber = !isPhoneValid(phoneNumber, countryCode);
    if (isInvalidPhoneNumber) {
      textInput.setCustomValidity(this.strings.invalid_phone || '');
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

  setExampleNumber() {
    const { exampleText, iti } = this;
    const { iso2 = 'us' } = iti.getSelectedCountryData();

    if (exampleText) {
      const { nationalMode } = iti.options;
      const numberType = intlTelInputUtils.numberType[iti.options.placeholderNumberType!];
      exampleText.textContent = intlTelInputUtils.getExampleNumber(iso2, nationalMode!, numberType);
    }
  }

  setCaptchaButtonExemption() {
    const { iso2 = 'us' } = this.iti.getSelectedCountryData();
    const isExempt =
      typeof this.captchaExemptCountries === 'boolean'
        ? this.captchaExemptCountries
        : this.captchaExemptCountries.includes(iso2.toUpperCase());

    if (isExempt) {
      this.captchaSubmitButton?.setAttribute('exempt', '');
    } else {
      this.captchaSubmitButton?.removeAttribute('exempt');
    }
  }
}

if (!customElements.get('lg-phone-input')) {
  customElements.define('lg-phone-input', PhoneInputElement);
}
