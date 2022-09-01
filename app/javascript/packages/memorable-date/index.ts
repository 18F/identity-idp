/**
 * Keys to lookup error messages for different states
 * of the MemorableDate element
 */
export enum MemorableDateErrorMessage {
  missing_month_day_year = 'missing_month_day_year',
  missing_month_day = 'missing_month_day',
  missing_month_year = 'missing_month_year',
  missing_day_year = 'missing_day_year',
  missing_month = 'missing_month',
  missing_day = 'missing_day',
  missing_year = 'missing_year',
  invalid_month = 'invalid_month',
  invalid_day = 'invalid_day',
  invalid_year = 'invalid_year',
  invalid_date = 'invalid_date',
  range_underflow = 'range_underflow',
  range_overflow = 'range_overflow',
  outside_date_range = 'outside_date_range',
}

/**
 * Type for a range check with a corresponding error message
 */
interface RangeErrorMessage {
  min?: string;
  max?: string;
  message: string;
}

/**
 * Type for a hash in which the specified messages can be looked up
 */
type MemorableDateErrorMessageLookup = Record<
  MemorableDateErrorMessage & string,
  string | undefined
>;

interface ErrorMessageLookupContainer {
  error_messages: MemorableDateErrorMessageLookup;
  range_errors: RangeErrorMessage[];
}

/**
 * The MemorableDate custom HTML element (WebComponent) provides
 * a broadly intuitive way for users to enter dates into web applications.
 *
 * More about the component here: https://designsystem.digital.gov/components/memorable-date/
 *
 * This class facilitates custom error checking and messaging for the MemorableDate
 * (<lg-memorable-date />) in combination with the ValidatedFieldElement
 * (<lg-validated-field />). The web server or another source is responsible for
 * adding the expected child elements for use with this WebComponent.
 */
class MemorableDateElement extends HTMLElement {
  /**
   * HTML input element for entering the month part of the date
   */
  get monthInput(): HTMLInputElement | null {
    return this.querySelector('.memorable-date__month');
  }

  /**
   * HTML input element for entering the day part of the date
   */
  get dayInput(): HTMLInputElement | null {
    return this.querySelector('.memorable-date__day');
  }

  /**
   * HTML input element for entering the year part of the date
   */
  get yearInput(): HTMLInputElement | null {
    return this.querySelector('.memorable-date__year');
  }

  /**
   * List of HTML input elements for entering month, day and year for a date
   */
  get allInputs(): HTMLInputElement[] {
    const month = this.monthInput;
    const day = this.dayInput;
    const year = this.yearInput;
    const inputs: HTMLInputElement[] = [];

    month && inputs.push(month);
    day && inputs.push(day);
    year && inputs.push(year);

    return inputs;
  }

  /**
   * The configured minimum valid value for the date, based on "min" HTML attribute
   */
  get min(): Date | null {
    return this.getDateAttribute('min');
  }

  /**
   * The configured maximum valid value for the date, based on "max" HTML attribute
   */
  get max(): Date | null {
    return this.getDateAttribute('max');
  }

  connectedCallback() {
    // Wait to show validation until first submission
    let updateErrorMessage = false;

    const { allInputs } = this;

    const inputListener = (e: Event) => {
      // Run validations
      this.validate();

      // Update error messages on form validation
      if (e.type === 'invalid') {
        updateErrorMessage = true;
      }

      if (updateErrorMessage) {
        // Trigger error message updates
        const errorMessage = allInputs.find((f) => f.validationMessage)?.validationMessage;
        allInputs.forEach((f) => {
          f.closest('lg-validated-field')?.setErrorMessage(errorMessage || null);
        });
      }
    };

    allInputs.forEach((i) => {
      i.addEventListener('input', inputListener);
      i.addEventListener('invalid', inputListener);
    });
  }

  validate(): void {
    const month = this.monthInput;
    const day = this.dayInput;
    const year = this.yearInput;

    if (!(month && day && year)) {
      // Cannot accurately run validation w/o all fields
      return;
    }

    const { error_messages: errorMessages, range_errors: rangeErrors } =
      this.getErrorMessageMappings();

    const hasMissingValues = [
      { month, day, year },
      { month, day },
      { month, year },
      { month },
      { day, year },
      { day },
      { year },
    ].some(this.checkMissingValues(errorMessages));

    if (hasMissingValues) {
      return;
    }

    const hasInvalidValues = [{ month }, { day }, { year }].some(
      this.checkFieldsInvalid(errorMessages),
    );

    if (hasInvalidValues) {
      return;
    }

    let parsedDate: Date | undefined;
    try {
      const parsedUnixTime = Date.parse(`${year.value}-${month.value}-${day.value}`);
      parsedDate = new Date(parsedUnixTime);
    } catch (e) {}

    // Check for cases where invalid dates could be "rolled over" into the next month
    // E.g. JavaScript could roll over February 29th in a non-leap year to March 1st
    //
    // Also bails if the date is otherwise invalid
    if (parsedDate?.getUTCDate() !== Number(day.value)) {
      if (errorMessages.invalid_date) {
        this.setValidity(errorMessages.invalid_date, month, day, year);
      }
      return;
    }

    const rangeError = this.getRangeError(errorMessages, rangeErrors, parsedDate);

    // Set range error if exists; otherwise clear previous value
    this.setValidity(rangeError || '', month, day, year);
  }

  /**
   * Check the given date against allowable date ranges and return the configured error message.
   * @param errorMessages Memorable date error message mapping
   * @param rangeErrors List of range errors for memorable date
   * @param date Date to compare against min, max, and allowable ranges
   * @returns Configured error message for range violations by the given date
   */
  private getRangeError(
    errorMessages: MemorableDateErrorMessageLookup,
    rangeErrors: RangeErrorMessage[],
    date: Date,
  ): string | undefined {
    const { min, max } = this;

    const minErrorMessage = errorMessages.range_underflow || errorMessages.outside_date_range;
    const maxErrorMessage = errorMessages.range_overflow || errorMessages.outside_date_range;

    if (minErrorMessage && min instanceof Date && date < min) {
      // Set range underflow error if applicable and messaging is available
      return minErrorMessage;
    }
    if (maxErrorMessage && max instanceof Date && date > max) {
      // Set range overflow error if applicable and messaging is available
      return maxErrorMessage;
    }
    // Set another range error if applicable and messaging is available
    return rangeErrors.find(
      ({ min: rangeMin, max: rangeMax }) =>
        (rangeMin && date < new Date(rangeMin)) || (rangeMax && date > new Date(rangeMax)),
    )?.message;
  }

  /**
   * @param attrName Name of attribute on this element containing a parseable date
   * @returns Date Javascript object parsed from the given attribute or null if it's misssing/invalid
   */
  private getDateAttribute(attrName: string): Date | null {
    const raw = this.getAttribute(attrName);
    if (raw === null) {
      return null;
    }

    const value = Date.parse(raw);
    if (Number.isNaN(value)) {
      return null;
    }
    return new Date(value);
  }

  /**
   * Set a custom error message on the given fields for use by a containing
   * ValidatedFieldElement.
   *
   * @param message Error message to display
   * @param fields Fields to which the error message applies
   */
  private setValidity(message: string, ...fields: HTMLInputElement[]): void {
    const { allInputs } = this;
    allInputs.forEach((field) => {
      if (fields.includes(field)) {
        field.setCustomValidity(message);
      } else {
        field.setCustomValidity('');
      }
    });
  }

  /**
   * @param errs Hash for looking up error messages
   * @returns Function to show errors for missing values on a group of elements
   */
  private checkMissingValues(errs: MemorableDateErrorMessageLookup) {
    return (fields: { [k: string]: HTMLInputElement | undefined }): boolean => {
      const message = errs[`missing_${Object.keys(fields).join('_')}`];
      const fieldValues = Object.values(fields);
      if (fieldValues.every((field) => !field?.value)) {
        message && this.setValidity(message, ...(fieldValues as HTMLInputElement[]));
        return true;
      }
      return false;
    };
  }

  /**
   * @param errs Hash for looking up error messages
   * @returns Function to show errors for invalid values on a group of elements
   */
  private checkFieldsInvalid(errs: MemorableDateErrorMessageLookup) {
    return (fields: { [k: string]: HTMLInputElement | undefined }): boolean => {
      const message = errs[`invalid_${Object.keys(fields).join('_')}`];
      const fieldValues = Object.values(fields);
      if (fieldValues.every((field) => field?.validity.patternMismatch)) {
        message && this.setValidity(message, ...(fieldValues as HTMLInputElement[]));
        return true;
      }
      return false;
    };
  }

  /**
   * @param entry Entry to check from Object.entries call
   * @returns True if the given entry is a valid mapping for memorable date errors
   */
  private isValidErrorMessage(entry: [string, any]): entry is [MemorableDateErrorMessage, string] {
    return (
      Array.isArray(entry) &&
      MemorableDateErrorMessage[entry[0]] === entry[0] &&
      typeof entry[1] === 'string'
    );
  }

  /**
   * @param rawLookup Hash
   * @returns Modified hash containing only valid memorable date error key/value pairs
   */
  private extractErrorMessages(rawLookup: Record<string, any>): MemorableDateErrorMessageLookup {
    return Object.fromEntries(
      Object.entries(rawLookup).filter(this.isValidErrorMessage),
    ) as MemorableDateErrorMessageLookup;
  }

  /**
   * @param rawErrors Hash array
   * @returns Modified hash array containing only values with valid range error messages
   */
  private extractRangeErrors(rawErrors: Record<string, any>[]): RangeErrorMessage[] {
    return rawErrors.filter((value): value is RangeErrorMessage => {
      if (!(value && typeof value === 'object')) {
        return false;
      }
      if (typeof value.message !== 'string') {
        return false;
      }

      const minDate = value.min === undefined ? null : Date.parse(value.min);
      const maxDate = value.max === undefined ? null : Date.parse(value.max);
      if (Number.isInteger(minDate) && Number.isInteger(maxDate)) {
        return minDate! < maxDate!;
      }
      return (
        (Number.isInteger(minDate) && maxDate === null) ||
        (Number.isInteger(maxDate) && minDate === null)
      );
    });
  }

  /**
   * Fetch and parse the error message mappings associated with this memorable date field
   * @returns Parsed error message mappings
   */
  private getErrorMessageMappings(): ErrorMessageLookupContainer {
    const errorMessageText =
      this.querySelector('.memorable-date__error-strings')?.textContent || '{}';
    let parsed: any;
    try {
      parsed = JSON.parse(errorMessageText);
    } catch (e) {
      // Invalid JSON error message text
    }

    let errorMessages: MemorableDateErrorMessageLookup = {} as MemorableDateErrorMessageLookup;
    if (parsed?.error_messages && typeof parsed?.error_messages === 'object') {
      errorMessages = this.extractErrorMessages(parsed.error_messages);
    }

    let rangeErrors: RangeErrorMessage[] = [];
    if (Array.isArray(parsed?.range_errors)) {
      rangeErrors = this.extractRangeErrors(parsed.range_errors);
    }

    return {
      error_messages: errorMessages,
      range_errors: rangeErrors,
    };
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-memorable-date': MemorableDateElement;
  }
}

if (!customElements.get('lg-memorable-date')) {
  customElements.define('lg-memorable-date', MemorableDateElement);
}
