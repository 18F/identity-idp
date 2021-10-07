import { isValidNumber } from 'libphonenumber-js';
import 'intl-tel-input/build/js/utils.js';
import * as intlTelInput from 'intl-tel-input/build/js/intlTelInput';

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
  connectedCallback() {
    /** @type {HTMLInputElement?} */
    this.textInput = this.querySelector('.phone-input__number');

    /** @type {HTMLSelectElement?} */
    this.codeInput = this.querySelector('.phone-input__international-code');

    this.codeWrapper = this.querySelector('.phone-input__international-code-wrapper');

    this.exampleText = this.querySelector('.phone-input__example');

    if (!this.textInput || !this.codeInput || !this.codeWrapper) {
      return;
    }

    this.codeWrapper.classList.add('display-none');

    this.iti = this.initializeIntlTelInput();

    this.textInput.addEventListener('countrychange', () => this.syncCountryChangeToCodeInput());
    this.textInput.addEventListener('input', () => this.validate());
    this.codeInput.addEventListener('change', () => this.formatTextInput());
    this.codeInput.addEventListener('change', () => this.updatePlaceholder());
    this.codeInput.addEventListener('change', () => this.validate());

    this.updatePlaceholder();
    this.validate();
  }

  get selectedOption() {
    const { codeInput } = this;

    return codeInput && codeInput.selectedOptions[0];
  }

  /** @return {string[]|undefined} */
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

    const input = intlTelInput(this.textInput, {
      preferredCountries: ['US', 'CA'],
      onlyCountries: supportedCountryCodes,
    });

    this.querySelectorAll('.iti').forEach((node) => {
      const iti = /** @type {HTMLDivElement} */ (node);

      // remove duplicate items in the country list
      /** @type {NodeListOf<HTMLLIElement>} */
      const preferred = iti.querySelectorAll('.iti__preferred');
      preferred.forEach((listItem) => {
        const { countryCode } = listItem.dataset;
        /** @type {NodeListOf<HTMLLIElement>} */
        const duplicates = iti.querySelectorAll(
          `.iti__standard[data-country-code="${countryCode}"]`,
        );
        duplicates.forEach((duplicateListItem) => {
          duplicateListItem.parentNode?.removeChild(duplicateListItem);
        });
      });

      // set accessibility label
      const flagContainer = iti.querySelectorAll('.iti__flag-container');
      if (flagContainer) {
        [].slice.call(flagContainer).forEach((element) => {
          element.setAttribute('aria-label', 'Country code');
        });
      }

      // fix knapsack error where aria-owns requires aria-expanded, use pop-up instead
      const selectedFlag = iti.querySelectorAll('.iti__flag-container .iti__selected-flag');
      if (selectedFlag) {
        [].slice.call(selectedFlag).forEach((element) => {
          element.setAttribute('aria-haspopup', 'true');
          element.setAttribute('role', 'button');
          element.removeAttribute('aria-owns');
        });
      }
    });

    return input;
  }

  validate() {
    const { textInput, codeInput } = this;
    if (textInput && codeInput && !isPhoneValid(textInput.value, codeInput.value)) {
      textInput.dispatchEvent(new CustomEvent('invalid'));
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

  updatePlaceholder() {
    const { textInput, exampleText } = this;

    if (textInput && textInput.placeholder && exampleText) {
      exampleText.textContent = textInput.placeholder;
      textInput.placeholder = '';
    }
  }
}
