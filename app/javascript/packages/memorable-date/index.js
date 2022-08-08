const dateValidity = (/** @type {any} */ month, day, year) => {
  // Month is off by 1 in js
  const date = new Date(year, month - 1, day);
  // eslint-disable-next-line no-console
  console.log('date: ', date);
  if (month <= 12 && month > 0) {
    // eslint-disable-next-line no-console
    console.log('valid');
    return true;
  }
  // eslint-disable-next-line no-console
  console.log('invalid');
  return false;
};

export class MemorableDate extends HTMLElement {
  connectedCallback() {
    this.addEventListener('input', this.validate);
    /** @type {HTMLInputElement?} */
    this.monthInput = this.querySelector('.memorable-date__month');
    /** @type {HTMLInputElement?} */
    this.dayInput = this.querySelector('.memorable-date__day');
    /** @type {HTMLInputElement?} */
    this.yearInput = this.querySelector('.memorable-date__year');

    if (!this.monthInput || !this.dayInput || !this.yearInput) {
      return;
    }

    this.validate();
  }

  validate() {
    const { monthInput, dayInput, yearInput } = this;
    if (!monthInput || !dayInput || !yearInput) {
      return;
    }
    const month = monthInput.value;
    const day = dayInput.value;
    const year = yearInput.value;

    const isInvalidDate = dateValidity(month, day, year);
    if (isInvalidDate) {
      // eslint-disable-next-line no-console
      console.log('month is invalid value:', isInvalidDate, day);
      // WILLDO: Err string
    }
  }
}
