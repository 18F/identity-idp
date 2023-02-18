import { t } from '@18f/identity-i18n';
import { trackError } from '@18f/identity-analytics';
import { request } from '@18f/identity-request';

interface ValidationResponse {
  success: boolean;
  data: Record<string, string>;
}

interface ValidationResultCache {
  previousValues: Record<string, string>;
  result: Record<string, string>;
}

const VALIDATION_URL_PATH = '/verify/in_person/validate_transliterable';
const VALIDATION_FORM_ERROR_CLASS = 'transliterable-form-error';

/**
 * This adds an asynchronous transliteration check for certain form fields
 * that gets run between form validation and submission.
 */
class TransliterableFieldGroupElement extends HTMLElement {
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
   *
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

  private get inputs(): Record<string, HTMLFormElement> {
    // Extract transliterable fields
    const { fieldMapping, form } = this;
    return Object.entries(fieldMapping).reduce((agg, [key, value]) => {
      agg[value] = form?.elements.namedItem(key) || null;
      return agg;
    }, {});
  }

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

  private get formSubmitButton() {
    return this.form?.querySelector('input[type=submit],button[type=submit]');
  }

  /**
   * Initializer for component
   */
  connectedCallback() {
    this.formSubmitButton?.addEventListener('click', this.handleSubmitClickEvent);

    // Attach event listener for form. Will not be attached redundantly
    // because function has same identity for multiple fields.
    // this.form?.addEventListener('submit', this.handleSubmitEvent, true);

    // TODO handle usability on slow Internet connections

    // Clear prior transliteration error when input gets updated
    this.input?.addEventListener('input', () => {
      const { input } = this;
      if (input?.validity.customError) {
        input.setCustomValidity('');
      }
    });
  }

  private lastFormSubmit: Promise<any> | null = null;

  private validationResultCache: ValidationResultCache = {
    previousValues: {},
    result: {},
  };

  /**
   * Intercept form submission attempts to ensure transliterable field validation
   * occurs first.
   */
  private readonly handleSubmitClickEvent = async (e: Event): Promise<void> => {
    const {
      inputs,
      inputValuesNeedingValidation,
      lastFormSubmit,
      handleAsyncValidation,
      setFormErrorVisibility,
    } = this;

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
      Object.values(inputs).forEach((field) => {
        // Prevent user from changing the fields between validation and submission
        field.readOnly = true;
      });
      this.lastFormSubmit = handleAsyncValidation();
      if (await this.lastFormSubmit) {
        setFormErrorVisibility(true);
      } else {
        setFormErrorVisibility(false);

        // Attempt to re-submit form. Infinite loop is prevented via the "inputValuesNeedingValidation" check.
        // Note: should not re-dispatch on network error
        setImmediate(() => e.target?.dispatchEvent(e));
      }
    } finally {
      // Always remove the promise, but only before the
      // attempted re-submission of the same form
      this.lastFormSubmit = null;

      Object.values(inputs).forEach((field) => {
        // Allow user to change fields after validation has finished; useful for fixing
        // validation or other errors that prevent submission.
        field.readOnly = false;
      });
    }
  };

  /**
   * Mediate interaction between the form and API:
   * - Marshal fields to API values
   * - Set errors based on API response
   * - Prevent form interactions that could cause unintuitive behavior
   * @return boolean Whether to show a form error on submit attempts
   */
  private readonly handleAsyncValidation = async (): Promise<boolean> => {
    const { inputs, inputValuesNeedingValidation: payload, sendValidationRequest } = this;
    try {
      const result = await sendValidationRequest(payload);

      this.validationResultCache = {
        previousValues: payload,
        result,
      };

      // Set custom validity on invalid fields; clear custom validity on valid fields
      Object.entries(inputs).forEach(([name, field]) => {
        const validationResult = result[name];
        console.log(name, payload[name], result[name]);
        field.previousValidatedValue = payload[name];
        field.input?.setCustomValidity(validationResult || '');
      });
      return false;
    } catch (err) {
      trackError(err);
      return true;
    }
  };

  /**
   * Update the visibility and message for the form-level error
   */
  private setFormErrorVisibility(visible: boolean) {
    const { formErrorElement } = this;

    if (!formErrorElement) {
      return;
    }

    const isVisible = !formErrorElement?.classList.contains('display-none');
    if (visible && !isVisible) {
      formErrorElement.textContent = t('in_person_proofing.form.state_id.errors.transliteration');
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
    const response = await request<ValidationResponse>(VALIDATION_URL_PATH, {
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
