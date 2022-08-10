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

  connectedCallback() {
    /** @type {HTMLInputElement?} */
    this.monthInput = this.querySelector('.memorable-date__month');
    /** @type {HTMLInputElement?} */
    this.dayInput = this.querySelector('.memorable-date__day');
    /** @type {HTMLInputElement?} */
    this.yearInput = this.querySelector('.memorable-date__year');

    if (!this.monthInput || !this.dayInput || !this.yearInput) {
      return;
    }

    this.addEventListener('input', this.validate);
    // error is set and can be found in class but is not displayed
  }

  validate() {
    const { monthInput, dayInput, yearInput } = this;
    if (!monthInput || !dayInput || !yearInput) {
      return;
    }
    const month = monthInput.value;
    const day = dayInput.value;
    const year = yearInput.value;

    const isvalidDate = isValidPastDate(month, day, year);

    if (!isvalidDate) {
      const errMessage = 'Date must be in the past';
      this.setErrorMessage(errMessage);
    }
  }

  /**
   * @param {any} message
   */
  setErrorMessage(message) {
    if (message) {
      const errClass = this.querySelector('.validated-field__error-strings');
      if (errClass) {
        errClass.textContent = message;
      }
    }
  }
}
