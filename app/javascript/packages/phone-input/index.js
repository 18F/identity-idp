import { isValidNumber } from 'libphonenumber-js';
import 'intl-tel-input/build/js/utils.js';
import intlTelInput from 'intl-tel-input';

/**
 * @typedef PhoneInputStrings
 *
 * @prop {string=} country_code_label
 * @prop {string=} invalid_phone
 */

/**
 * @typedef IntlTelInputUtilsGlobal
 *
 * @prop {(iso2: string, nationalMode: boolean, numberType: string) => string} getExampleNumber
 * @prop {Record<string, string>} numberType
 */

const {
  intlTelInputUtils,
} = /** @type {window & { intlTelInputUtils: IntlTelInputUtilsGlobal }} */ (window);

const INTERNATIONAL_CODE_REGEX = /^\+(\d+) |^1 /;

const isPhoneValid = (phone, countryCode) => {
  let phoneValid = isValidNumber(phone, countryCode);
  if (!phoneValid && countryCode === 'US') {
    phoneValid = isValidNumber(`+1 ${phone}`, countryCode);
  }
  return phoneValid;
};

const internationalCodeFromPhone = (phone) => {
  const match = phone.match(INTERNATIONAL_CODE_REGEX);
  if (match) {
    return match[1] || match[2];
  }
  return '1';
};

const updateInternationalCodeInPhone = (phone, newCode) =>
  phone.replace(new RegExp(`^\\+?(\\d+\\s+|${newCode})?`), `+${newCode} `);

export class PhoneInput extends HTMLElement {
  /** @type {PhoneInputStrings} */
  #_strings;

  connectedCallback() {
    /** @type {HTMLInputElement?} */
    this.textInput = this.querySelector('.phone-input__number');
    /** @type {HTMLSelectElement?} */
    this.codeInput = this.querySelector('.phone-input__international-code');
    this.codeWrapper = this.querySelector('.phone-input__international-code-wrapper');
    this.exampleText = this.querySelector('.phone-input__example');

    if (!this.textInput || !this.codeInput) {
      return;
    }

    this.iti = this.initializeIntlTelInput();

    this.textInput.addEventListener('countrychange', () => this.syncCountryChangeToCodeInput());
    this.textInput.addEventListener('input', () => this.validate());
    this.codeInput.addEventListener('change', () => this.formatTextInput());
    this.codeInput.addEventListener('change', () => this.setExampleNumber());
    this.codeInput.addEventListener('change', () => this.validate());

    this.setExampleNumber();
    this.validate();
  }

  get selectedOption() {
    const { codeInput } = this;

    return codeInput && codeInput.options[codeInput.selectedIndex];
  }

  /**
   * @return {string[]|undefined}
   */
  get supportedCountryCodes() {
    const { codeInput } = this;

    if (codeInput && codeInput.dataset.countries) {
      try {
        return JSON.parse(codeInput.dataset.countries);
      } catch {}
    }

    return undefined;
  }

  /**
   * @return {PhoneInputStrings}
   */
  get strings() {
    if (!this.#_strings) {
      try {
        this.#_strings = JSON.parse(this.querySelector('.phone-input__strings')?.textContent || '');
      } catch {
        this.#_strings = {};
      }
    }

    return this.#_strings;
  }

  /**
   * Mirrors country change to the hidden select field, which holds the value for form submission.
   */
  syncCountryChangeToCodeInput() {
    /** @type {{iso2?:string}} */
    const country = this.iti.getSelectedCountryData();
    if (country.iso2 && this.codeInput) {
      this.codeInput.value = country.iso2.toUpperCase();
      this.codeInput.dispatchEvent(new CustomEvent('change', { bubbles: true }));
    }
  }

  initializeIntlTelInput() {
    const { supportedCountryCodes } = this;

    const iti = intlTelInput(this.textInput, {
      preferredCountries: ['US', 'CA'],
      onlyCountries: supportedCountryCodes,
      autoPlaceholder: 'off',
    });

    // Remove duplicate items in the country list
    /** @type {NodeListOf<HTMLLIElement>} */
    const preferred = iti.countryList.querySelectorAll('.iti__preferred');
    preferred.forEach((listItem) => {
      const { countryCode } = listItem.dataset;
      /** @type {NodeListOf<HTMLLIElement>} */
      const duplicates = iti.countryList.querySelectorAll(
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

    return iti;
  }

  validate() {
    const { textInput, codeInput } = this;
    if (textInput && codeInput) {
      const isValid = isPhoneValid(textInput.value, codeInput.value);
      const validity = (!isValid && this.strings.invalid_phone) || '';
      textInput.setCustomValidity(validity);
    }
  }

  formatTextInput() {
    const { textInput, selectedOption } = this;
    if (!textInput || !selectedOption) {
      return;
    }

    const phone = textInput.value;
    const inputInternationalCode = internationalCodeFromPhone(phone);
    const selectedInternationalCode = selectedOption.dataset.countryCode;

    if (inputInternationalCode !== selectedInternationalCode) {
      textInput.value = updateInternationalCodeInPhone(phone, selectedInternationalCode);
    }
  }

  /**
   * Returns true if the delivery option is valid for the selected option, or false otherwise.
   *
   * @param {string} delivery
   * @return {boolean}
   */
  isDeliveryOptionSupported(delivery) {
    const { selectedOption } = this;

    return !!selectedOption && selectedOption.getAttribute(`data-supports-${delivery}`) !== 'false';
  }

  setExampleNumber() {
    const { exampleText, iti } = this;
    const { iso2 = 'us' } = iti.selectedCountryData;

    if (exampleText) {
      const { nationalMode } = iti.options;
      const numberType = intlTelInputUtils.numberType[iti.options.placeholderNumberType];
      exampleText.textContent = intlTelInputUtils.getExampleNumber(iso2, nationalMode, numberType);
    }
  }
}
