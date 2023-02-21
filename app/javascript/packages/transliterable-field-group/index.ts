import { trackError } from '@18f/identity-analytics';
import { request } from '@18f/identity-request';

/**
 * Representation of the response from a transliteration API call
 */
interface ValidationResponse {
  success: boolean;
  data: Record<string, string>;
}

/**
 * Internal cache structure for controlling when API call is made
 * and reusing result
 */
interface ValidationResultCache {
  previousValues: Record<string, string>;
  result: Record<string, string>;
}

/**
 * This adds an asynchronous transliteration check for certain form fields
 * that gets run between form validation and submission.
 */
class TransliterableFieldGroupElement extends HTMLElement {
  private static readonly DEFAULT_INPUT_TIMEOUT_MS = 1500;

  /**
   * Cache to moderate API calls and allow reuse of the previous result
   */
  private validationResultCache: ValidationResultCache = {
    previousValues: {},
    result: {},
  };

  private lastRevalidationRequest: Promise<void>;

  private lastFormSubmit: Promise<any> | null = null;

  /**
   * Form associated with this element
   */
  get form(): HTMLFormElement | null {
    let element: HTMLElement | null = this;
    do {
      element = element.parentElement;
    } while (element && !(element instanceof HTMLFormElement));
    return element;
  }

  /**
   * URL to fetch from for validating that fields are transliterable
   */
  get validationUrl(): string | null {
    return this.getAttribute('validation-url');
  }

  /**
   * Time to wait for input to stop before validating for transliterability
   */
  get inputTimeoutMilliseconds(): number {
    const attrNumber = Number(this.getAttribute('input-timeout-ms'));
    if (Number.isNaN(attrNumber) || attrNumber < 0) {
      return TransliterableFieldGroupElement.DEFAULT_INPUT_TIMEOUT_MS;
    }
    return attrNumber;
  }

  /**
   * Element that displays general form errors to the user
   */
  get formErrorElement(): Element | null {
    const selector = this.getAttribute('form-error-selector');
    if (selector) {
      return this.form?.querySelector(selector) || null;
    }

    return null;
  }

  /**
   * Mapping of regular field names to transliteration API field names
   */
  get fieldMapping(): Record<string, string> {
    const rawFields = this.getAttribute('field-mapping');
    if (rawFields) {
      try {
        return JSON.parse(rawFields);
      } catch (e) {
        trackError(e);
      }
    }
    return {};
  }

  /**
   * Input elements mapped by their transliteration API field names
   */
  private get inputs(): Record<string, HTMLInputElement> {
    // Extract transliterable fields
    const { fieldMapping, form } = this;
    return Object.entries(fieldMapping).reduce((agg, [key, value]) => {
      const element = form?.elements.namedItem(key);
      if (element instanceof HTMLInputElement) {
        agg[value] = element;
      }
      return agg;
    }, {});
  }

  /**
   * Input elements that haven't been validated using the API,
   * mapped by their transliteration API field names
   */
  private get inputValuesNeedingValidation(): Record<string, string> {
    const {
      inputs,
      validationResultCache: { previousValues },
    } = this;
    const inputEntries = Object.entries(inputs);
    return inputEntries.reduce((agg: Record<string, string>, [name, field]) => {
      if (previousValues[name] !== field.value) {
        agg[name] = field.value;
      }
      return agg;
    }, {});
  }

  /**
   * Submit button associated with the current form
   */
  private get formSubmitButton() {
    return this.form?.querySelector('input[type=submit],button[type=submit]');
  }

  /**
   * Initializer for component
   */
  connectedCallback() {
    // Setup input validation triggers
    Object.values(this.inputs).forEach((input) => {
      input.addEventListener('input', this.revalidateInput);
    });

    // Intercept form submission to allow validation to complete.
    //
    // Catching the "click" instead of "submit" helps in making the info available
    // before native browser validation is triggered.
    this.formSubmitButton?.addEventListener('click', this.handleSubmitClickEvent, true);
  }

  /**
   * Clear the input validation status, then trigger re-validation of the
   * transliterable fields.
   *
   * @param input HTMLInputElement
   */
  private async revalidateInput({ currentTarget: input }: Partial<Event> = {}): Promise<void> {
    if (input instanceof HTMLInputElement && input.validity.customError) {
      // Remove current error text
      input.setCustomValidity('');
    }
    try {
      await this.revalidateAllInputs(this.inputTimeoutMilliseconds);
    } catch (err) {
      trackError(err);
    }
  }

  /**
   * Re-validate the transliterable fields. Uses a debouncing strategy
   * to ensure that only the latest field values get validated.
   */
  private revalidateAllInputs(timeout: number = 0): Promise<void> {
    // Debounce to prevent excessive API calls
    const promise: Promise<void> = new Promise((resolve, reject) => {
      setTimeout(async () => {
        if (this.lastRevalidationRequest !== promise) {
          // Defer to newest call for results
          this.lastRevalidationRequest.then(resolve, reject);
        } else if (Object.values(this.inputValuesNeedingValidation).length < 1) {
          resolve();
        }

        let err: Error | undefined;
        try {
          await this.handleAsyncValidation();
        } catch (e) {
          err = e;
        }

        if (this.lastRevalidationRequest !== promise) {
          // Defer to newest call for results (important to check this after async delay)
          this.lastRevalidationRequest.then(resolve, reject);
        } else if (err) {
          reject(err);
        } else {
          resolve();
        }
      }, timeout);
    });
    this.lastRevalidationRequest = promise;
    return promise;
  }

  /**
   * Intercept form submission attempts to ensure transliterable field validation
   * occurs first.
   */
  private readonly handleSubmitClickEvent = async (e: Event): Promise<void> => {
    const { inputValuesNeedingValidation, lastFormSubmit, setFormErrorVisibility } = this;

    if (Object.keys(inputValuesNeedingValidation).length < 1) {
      // None of the transliterable fields need to be checked
      return;
    }

    // Delay form submission
    e.preventDefault();

    // Stop additional form submission-related behaviors
    // E.g. submit button disablement
    e.stopImmediatePropagation();

    if (lastFormSubmit) {
      // Prevent redundant calls
      return;
    }

    try {
      // Note: This will automatically wait for additional transliteration API calls if
      // the user updates the fields before submission.
      this.lastFormSubmit = this.revalidateAllInputs();
      await this.lastFormSubmit;

      setFormErrorVisibility(false);

      // Attempt to re-submit form. Infinite loop is prevented via the "inputValuesNeedingValidation" check.
      // Note: should not re-dispatch on network error
      setImmediate(() => e.target?.dispatchEvent(e));
    } catch (err) {
      trackError(err);
      setFormErrorVisibility(true);
    } finally {
      // Always remove the promise, but only before the
      // attempted re-submission of the same form
      this.lastFormSubmit = null;
    }
  };

  /**
   * Query transliterable field validation API, then set
   * validation on fields
   * @return boolean Whether to show a form error on submit attempts
   */
  private readonly handleAsyncValidation = async (): Promise<void> => {
    const { inputs, inputValuesNeedingValidation: payload, sendValidationRequest } = this;

    const result = await sendValidationRequest(payload);

    const { previousValues, result: resultCache } = this.validationResultCache;

    Object.assign(previousValues, payload);
    Object.assign(resultCache, result);

    // Set custom validity on invalid fields; clear custom validity on valid fields
    Object.entries(inputs).forEach(([name, field]) => {
      field.setCustomValidity(resultCache[name] || '');
    });
  };

  /**
   * Update the visibility for the form-level error
   */
  private setFormErrorVisibility(visible: boolean) {
    const { formErrorElement } = this;

    if (!formErrorElement) {
      return;
    }

    const isVisible = !formErrorElement?.classList.contains('display-none');
    if (visible && !isVisible) {
      formErrorElement.className = Array.from(formErrorElement.classList)
        .filter((c) => c !== 'display-none')
        .join(' ');
    } else if (!visible && isVisible) {
      formErrorElement.className += ' display-none';
    }
  }

  /**
   * Wrapper for transliteration API call
   */
  private async sendValidationRequest(
    fields: Record<string, string>,
  ): Promise<Record<string, string>> {
    const { validationUrl } = this;
    if (!validationUrl) {
      // Component is not correctly configured
      throw new Error('Validation URL not set');
    }
    const response = await request<ValidationResponse>(validationUrl, {
      method: 'POST',
      body: JSON.stringify(fields),
    });

    if (response.success) {
      return response.data;
    }
    throw new Error('Failed to retrieve validation data');
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-transliterable-field-group': TransliterableFieldGroupElement;
  }
}

if (!customElements.get('lg-transliterable-field-group')) {
  customElements.define('lg-transliterable-field-group', TransliterableFieldGroupElement);
}
