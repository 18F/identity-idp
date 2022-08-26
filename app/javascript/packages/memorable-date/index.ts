
/**
 * Keys to lookup error messages for different states
 * of the MemorableDate element
 */
export enum MemorableDateErrorMessage {
  missing_month_day_year = 'missing_month_day_year',
  missing_month_day = 'missing_month_day',
  missing_month_year = 'missing_month_year',
  missing_day_year = 'missing_day_year',
  invalid_month = 'invalid_month',
  invalid_day = 'invalid_day',
  invalid_year = 'invalid_year',
  invalid_date = 'invalid_date',
  range_underflow = 'range_underflow',
  range_overflow = 'range_overflow',
  outside_date_range = 'outside_date_range',
}

interface RangeErrorMessage {
  min?: string;
  max?: string;
  message: string;
}

/**
 * Type for a hash in which the specified messages can be looked up
 */
type MemorableDateErrorMessageLookup = Record<MemorableDateErrorMessage & string,string|undefined>;

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
  // Fetch DOM-related data dynamically to avoid
  // storing outdated information

  get monthInput(): HTMLInputElement | null {
    return this.querySelector('.memorable-date__month');
  }

  get dayInput(): HTMLInputElement | null {
    return this.querySelector('.memorable-date__day');
  }

  get yearInput(): HTMLInputElement | null {
    return this.querySelector('.memorable-date__year');
  }

  get min(): Date | null {
    return this.getDateAttribute('min');
  }

  get max(): Date | null {
    return this.getDateAttribute('max');
  }

  get errorMessages(): ErrorMessageLookupContainer {
    const errorMessageText = this.querySelector('.memorable-date__error-strings')?.textContent || '{}';
    let parsed: any;
    try {
      parsed = JSON.parse(errorMessageText);
    } catch (e) {
      // Invalid JSON error message text
    }

    let errorMessages: MemorableDateErrorMessageLookup = {} as MemorableDateErrorMessageLookup;
    if (parsed?.error_messages && typeof parsed?.error_messages === "object") {
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

  connectedCallback() {
    this.addEventListener('input', () => this.validate());
  }

  validate() {
    const month = this.monthInput;
    const day = this.dayInput;
    const year = this.yearInput;

    if (month === null || day === null || year === null) {
      // Cannot accurately run validation w/o all fields
      return;
    }

    // Clear previous value
    this.setValidity('', month, day, year);

    const { error_messages: errorMessages } = this.errorMessages;
    const hasMissingValues = [
      {month, day, year},
      {month, day},
      {month, year},
      {month},
      {day, year},
      {day},
      {year},
    ].some(this.checkMissingValues(errorMessages));

    if (hasMissingValues) {
      return;
    }

    const hasInvalidValues = [
      {month},
      {day},
      {year},
    ].some(this.checkFieldsInvalid(errorMessages))

    if (hasInvalidValues) {
      return;
    }

    const parsedUnixTime = Date.parse(`${year.value}-${month.value}-${day.value}`);
    if (errorMessages.invalid_date && isNaN(parsedUnixTime)) {
      this.setValidity(errorMessages.invalid_date, month, day, year);
      return;
    }

    const parsedDate = new Date(parsedUnixTime);

    const min = this.min;
    const minErrorMessage = errorMessages.range_underflow || errorMessages.outside_date_range;
    const underMin = minErrorMessage && min instanceof Date && parsedDate < min;

    const max = this.max;
    const maxErrorMessage = errorMessages.range_overflow || errorMessages.outside_date_range;
    const overMax = maxErrorMessage && max instanceof Date && parsedDate > max;

    if (underMin) {
      this.setValidity(minErrorMessage, month, day, year);
    } else if (overMax) {
      this.setValidity(maxErrorMessage, month, day, year);
    }
  }

  private getDateAttribute(attrName: string): Date | null {
    const raw = this.getAttribute(attrName);
    if (raw === null) {
      return null;
    }

    const value = Date.parse(raw);
    if (isNaN(value)) {
      return null;
    } else {
      return new Date(value);
    }
  }

  private setValidity (message: string, ...fields: HTMLInputElement[]): void {
    fields.forEach((field: HTMLInputElement) => field.setCustomValidity(message));
  }

  private checkMissingValues (errs: MemorableDateErrorMessageLookup) {
    return (fields: { [k: string]: HTMLInputElement | undefined }): boolean => {
      const message = errs[`missing_${Object.keys(fields).join('_')}`];
      const fieldValues = Object.values(fields);
      if (message && fieldValues.every(field => !field?.value)) {
        this.setValidity(message, ...(fieldValues as HTMLInputElement[]));
        return true;
      }
      return false;
    }
  }

  private checkFieldsInvalid (errs: MemorableDateErrorMessageLookup) {
    return (fields: { [k: string]: HTMLInputElement | undefined }): boolean => {
      const message = errs[`invalid_${Object.keys(fields).join('_')}`];
      const fieldValues = Object.values(fields);
      if (message && fieldValues.every(field => field?.validity.patternMismatch)) {
        this.setValidity(message, ...(fieldValues as HTMLInputElement[]));
        return true;
      }
      return false;
    };
  }

  private isValidErrorMessage (entry: [string, any]): entry is [MemorableDateErrorMessage, string] {
    return Array.isArray(entry) &&
      MemorableDateErrorMessage[entry[0]] === entry[0] &&
      typeof entry[1] === 'string';
  }

  private extractErrorMessages(input: Record<string,any>): MemorableDateErrorMessageLookup {
      return Object.entries<Record<string,any>>(input)
        .reduce((a, entry) => {
          if (this.isValidErrorMessage(entry)) {
            return {
              ...a,
              [entry[0]]: entry[1],
            };
          }
          return a;
      }, {} as MemorableDateErrorMessageLookup);
  }

  private extractRangeErrors(input: Record<string,any>[]): RangeErrorMessage[] {
    return input.filter((value): value is RangeErrorMessage => {
      return false;
    });
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
