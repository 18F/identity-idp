const isValidPastDate = (
  /** @type {any} */ month,
  /** @type {any} */ day,
  /** @type {any} */ year,
) => {
  const todaysDate = new Date();

  if (year > todaysDate.getFullYear()) {
    return false;
  }

  // Month is off by 1 in js
  if (
    month >= todaysDate.getMonth() + 1 &&
    day >= todaysDate.getDate() &&
    year >= todaysDate.getFullYear()
  ) {
    return false;
  }
  return true;
};

export class MemorableDate extends HTMLElement {
  /** @type {HTMLElement?} */
  errorMessage;

  /** @type {HTMLElement?} */
  customErrorElement;

  connectedCallback() {
    /** @type {HTMLInputElement?} */
    this.monthInput = this.querySelector('.memorable-date__month');
    /** @type {HTMLInputElement?} */
    this.dayInput = this.querySelector('.memorable-date__day');
    /** @type {HTMLInputElement?} */
    this.yearInput = this.querySelector('.memorable-date__year');
    this.customErrorElement = this.querySelector('.memorable-date-custom-error');

    if (!this.monthInput || !this.dayInput || !this.yearInput) {
      return;
    }

    this.addEventListener('input', this.validate);
  }

  validate() {
    const { monthInput, dayInput, yearInput } = this;
    if (!monthInput || !dayInput || !yearInput) {
      return;
    }
    const month = monthInput.value;
    const day = dayInput.value;
    const year = yearInput.value;

    const isvalid = isValidPastDate(month, day, year);

    if (!isvalid) {
      const errMessage = 'Enter a date that is in the past';
      this.displayError(errMessage);
    }
  }

  /**
   * @param {any} message
   */
  displayError(message) {
    if (message) {
      const errClass = this.querySelector('.validated-field__error-strings');
      if (errClass) {
        errClass.textContent = message;
        this.errorMessage = this.ownerDocument.createElement('div');
        this.errorMessage.classList.add('usa-error-message');
        this.errorMessage.textContent = message;
        this.customErrorElement?.appendChild(this.errorMessage);
        this.monthInput?.classList.add('usa-input--error');
        this.dayInput?.classList.add('usa-input--error');
        this.yearInput?.classList.add('usa-input--error');
      }
    }
  }
}
