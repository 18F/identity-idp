import { t } from '@18f/identity-i18n';

const isValidPastDate = (month: any, day: any, year: any) => {
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
  errorMessage: HTMLElement;

  customErrorElement: HTMLElement | null;

  monthInput: HTMLInputElement | null;

  dayInput: HTMLInputElement | null;

  yearInput: HTMLInputElement | null;

  connectedCallback() {
    this.monthInput = this.querySelector('.memorable-date__month');
    this.dayInput = this.querySelector('.memorable-date__day');
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
      const errMessage = t('simple_form.errors.future_date');
      this.displayError(errMessage);
    }
  }

  displayError(message: string) {
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
