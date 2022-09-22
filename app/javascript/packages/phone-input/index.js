import { isValidNumber, isValidNumberForRegion } from 'libphonenumber-js';
import 'intl-tel-input/build/js/utils.js';
import intlTelInput from 'intl-tel-input';
import { replaceVariables } from '@18f/identity-i18n';

/** @typedef {import('libphonenumber-js').CountryCode} CountryCode */

/**
 * @typedef PhoneInputStrings
 *
 * @prop {string=} country_code_label
 * @prop {string=} invalid_phone
 * @prop {string=} unsupported_country
 */

/**
 * @typedef IntlTelInputUtilsGlobal
 *
 * @prop {(iso2: string, nationalMode: boolean, numberType: string) => string} getExampleNumber
 * @prop {Record<string, string>} numberType
 */

const { intlTelInputUtils } =
  /** @type {window & { intlTelInputUtils: IntlTelInputUtilsGlobal }} */ (window);

const isPhoneValid = (phone, countryCode) => {
  let phoneValid = isValidNumber(phone, countryCode);
  if (!phoneValid && countryCode === 'US') {
    phoneValid = isValidNumber(`+1 ${phone}`, countryCode);
  }
  return phoneValid;
};

const updateInternationalCodeInPhone = (phone, newCode) =>
  phone.replace(new RegExp(`^\\+?(\\d+\\s+|${newCode})?`), `+${newCode} `);

export class PhoneInput extends HTMLElement {
  /** @type {PhoneInputStrings} */
  #strings;

  /** @type {string[]} */
  deliveryMethods = [];

  /** @type {Object.<string,*>} */
  countryCodePairs = {};

  connectedCallback() {
    /** @type {HTMLInputElement?} */
    this.textInput = this.querySelector('.phone-input__number');
    /** @type {HTMLSelectElement?} */
    this.codeInput = this.querySelector('.phone-input__international-code');
    this.codeWrapper = this.querySelector('.phone-input__international-code-wrapper');
    this.exampleText = this.querySelector('.phone-input__example');

    try {
      this.deliveryMethods = JSON.parse(this.dataset.deliveryMethods || '');
      this.countryCodePairs = JSON.parse(this.dataset.translatedCountryCodeNames || '');
    } catch {}

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
    if (!this.#strings) {
      try {
        this.#strings = JSON.parse(this.querySelector('.phone-input__strings')?.textContent || '');
      } catch {
        this.#strings = {};
      }
    }

    return this.#strings;
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
    const { supportedCountryCodes, countryCodePairs } = this;
    const allowDropdown = supportedCountryCodes && supportedCountryCodes.length > 1;

    const iti = intlTelInput(this.textInput, {
      preferredCountries: ['US', 'CA'],
      localizedCountries: countryCodePairs,
      onlyCountries: supportedCountryCodes,
      autoPlaceholder: 'off',
      allowDropdown,
    });

    if (allowDropdown) {
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
    }

    return iti;
  }

  validate() {
    const { textInput, codeInput, supportedCountryCodes, selectedOption } = this;
    if (!textInput || !codeInput || !selectedOption) {
      return;
    }

    const phoneNumber = textInput.value;
    const countryCode = /** @type {CountryCode} */ (codeInput.value);

    textInput.setCustomValidity('');
    if (!phoneNumber) {
      return;
    }

    const isInvalidCountry =
      supportedCountryCodes?.length === 1 && !isValidNumberForRegion(phoneNumber, countryCode);
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
   *
   * @param {string} delivery
   * @return {boolean}
   */
  isDeliveryOptionSupported(delivery) {
    const { selectedOption } = this;

    return !!selectedOption && selectedOption.getAttribute(`data-supports-${delivery}`) !== 'false';
  }

  /**
   * Returns true if the currently selected country can receive a supported delivery options, or
   * false otherwise.
   *
   * @return {boolean} Whether selected country is supported.
   */
  isSupportedCountry() {
    return this.deliveryMethods.some((delivery) => this.isDeliveryOptionSupported(delivery));
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
