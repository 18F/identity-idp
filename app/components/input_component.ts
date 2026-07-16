import { AsYouType } from 'libphonenumber-js';
import type { CountryCode } from 'libphonenumber-js';
import { bindFormSubmitters } from '@18f/identity-validated-field/form-submitters';

const DEFAULT_COUNTRY: CountryCode = 'US';
const ADS_VALIDATION_READY = 'adsValidationReady';
const ADS_FORM_VALIDATION_READY = 'adsFormValidationReady';
const VALIDATION_CONTROL_SELECTOR = '.ads-input__control, .validated-field__input';

type ValidationControl = HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement;

const digitCount = (value: string) => value.replace(/\D/g, '').length;

const caretPositionAfterDigits = (value: string, count: number) => {
  if (count <= 0) {
    return 0;
  }

  let seen = 0;
  for (let i = 0; i < value.length; i += 1) {
    if (/\d/.test(value[i])) {
      seen += 1;
      if (seen === count) {
        return i + 1;
      }
    }
  }

  return value.length;
};

export const formatPhoneInput = (
  phoneField: HTMLInputElement,
  country: CountryCode,
  { preserveCaret = true } = {},
) => {
  const before = phoneField.value;
  const caret = phoneField.selectionStart ?? before.length;
  const digitsBeforeCaret = digitCount(before.slice(0, caret));
  const after = new AsYouType(country).input(before);

  if (after === before) {
    return;
  }

  phoneField.value = after;

  if (preserveCaret && document.activeElement === phoneField) {
    const next = caretPositionAfterDigits(after, digitsBeforeCaret);
    phoneField.setSelectionRange(next, next);
  }
};

const syncDialCode = (countrySelect: HTMLSelectElement) => {
  const dialCode = countrySelect
    .closest('.ads-input__country-shell')
    ?.querySelector('[data-ads-phone-country-value]');
  const option = countrySelect.options[countrySelect.selectedIndex];
  if (dialCode && option) {
    dialCode.textContent = option.dataset.dialCode || '';
  }
};

const bindPhoneInput = (phoneField: HTMLInputElement) => {
  if (phoneField.dataset.adsPhoneInputReady === 'true') {
    return;
  }
  phoneField.dataset.adsPhoneInputReady = 'true';

  const countrySelect = phoneField
    .closest('.ads-input')
    ?.querySelector<HTMLSelectElement>('[data-ads-phone-country]');
  const country = () => (countrySelect?.value || DEFAULT_COUNTRY) as CountryCode;

  phoneField.addEventListener('input', () => formatPhoneInput(phoneField, country()));
  countrySelect?.addEventListener('change', () => {
    syncDialCode(countrySelect);
    formatPhoneInput(phoneField, country(), { preserveCaret: false });
  });

  if (countrySelect) {
    syncDialCode(countrySelect);
  }
  if (phoneField.value.trim()) {
    formatPhoneInput(phoneField, country(), { preserveCaret: false });
  }
};

export const enhancePhoneInputs = (root: ParentNode = document) => {
  root.querySelectorAll<HTMLInputElement>('[data-ads-phone-input]').forEach(bindPhoneInput);
};

const syncPasswordToggle = (input: HTMLInputElement, button: HTMLButtonElement) => {
  const showIcon = button.querySelector('[data-ads-password-icon-show]');
  const hideIcon = button.querySelector('[data-ads-password-icon-hide]');
  const isPassword = input.type === 'password';
  const label = isPassword ? button.dataset.labelShow : button.dataset.labelHide;

  showIcon?.toggleAttribute('hidden', !isPassword);
  hideIcon?.toggleAttribute('hidden', isPassword);

  if (label) {
    button.setAttribute('aria-label', label);
  }

  button.setAttribute('aria-pressed', String(!isPassword));
};

const passwordInputForToggle = (button: HTMLButtonElement) => {
  const controls = button.getAttribute('aria-controls');
  const byId = controls ? document.getElementById(controls) : null;
  return byId instanceof HTMLInputElement ? byId : null;
};

/** Password toggles in the same form stay in sync (password + confirmation). */
const relatedPasswordToggles = (button: HTMLButtonElement) => {
  const scope: ParentNode = button.closest('form') ?? document;
  return Array.from(scope.querySelectorAll<HTMLButtonElement>('[data-ads-password-toggle]'));
};

const bindPasswordToggle = (button: HTMLButtonElement) => {
  if (button.dataset.adsPasswordToggleReady === 'true') {
    return;
  }

  const input = passwordInputForToggle(button);
  if (!input) {
    return;
  }

  button.dataset.adsPasswordToggleReady = 'true';
  syncPasswordToggle(input, button);

  button.addEventListener('mousedown', (event) => {
    event.preventDefault();
  });

  button.addEventListener('click', () => {
    const nextType = input.type === 'password' ? 'text' : 'password';
    relatedPasswordToggles(button).forEach((relatedButton) => {
      const relatedInput = passwordInputForToggle(relatedButton);
      if (!relatedInput) {
        return;
      }
      relatedInput.type = nextType;
      syncPasswordToggle(relatedInput, relatedButton);
    });
    input.focus();
  });
};

export const enhancePasswordToggles = (root: ParentNode = document) => {
  root
    .querySelectorAll<HTMLButtonElement>('[data-ads-password-toggle]')
    .forEach(bindPasswordToggle);
};

const ERROR_INNER_CLASS = 'ads-input__error-inner';
const VISIBLE_ERROR_CLASS = 'ads-input__error--visible';

const descriptorIdRefs = (input: ValidationControl) =>
  input.getAttribute('aria-describedby')?.split(' ').filter(Boolean) || [];

const existingErrorForInput = (input: ValidationControl) =>
  input.closest('.ads-input')?.querySelector<HTMLElement>('.ads-input__error') || null;

const errorIdForInput = (input: ValidationControl, errorMessage?: HTMLElement | null) => {
  if (errorMessage?.id) {
    return errorMessage.id;
  }

  const baseId = input.id || input.name || 'field';
  return `${baseId}_ads_error`;
};

const setInputDescribedBy = (input: ValidationControl, errorId: string, hasError: boolean) => {
  const idRefs = descriptorIdRefs(input).filter((idRef) => idRef !== errorId);
  if (hasError) {
    idRefs.push(errorId);
  }

  if (idRefs.length) {
    input.setAttribute('aria-describedby', idRefs.join(' '));
  } else {
    input.removeAttribute('aria-describedby');
  }
};

const ensureErrorInner = (error: HTMLElement) => {
  let inner = error.querySelector<HTMLElement>(`.${ERROR_INNER_CLASS}`);
  if (inner) {
    return inner;
  }

  inner = document.createElement('span');
  inner.className = ERROR_INNER_CLASS;
  if (error.textContent) {
    inner.textContent = error.textContent;
    error.textContent = '';
  }
  error.appendChild(inner);
  return inner;
};

const insertErrorMessage = (input: ValidationControl, errorMessage: HTMLElement) => {
  const container = input.closest('.ads-input');
  if (!container) {
    return;
  }

  const inputShell = container.querySelector('.ads-input__phone-shell, .ads-input__shell');
  if (inputShell) {
    inputShell.insertAdjacentElement('afterend', errorMessage);
  } else {
    container.appendChild(errorMessage);
  }
};

const getOrCreateErrorMessage = (input: ValidationControl) => {
  const existing = existingErrorForInput(input);
  if (existing) {
    return existing;
  }

  const errorMessage = document.createElement('p');
  errorMessage.className = 'ads-input__error';
  errorMessage.id = errorIdForInput(input);
  errorMessage.setAttribute('aria-live', 'polite');
  errorMessage.setAttribute('data-ads-error', '');
  const inner = document.createElement('span');
  inner.className = ERROR_INNER_CLASS;
  errorMessage.appendChild(inner);
  insertErrorMessage(input, errorMessage);

  return errorMessage;
};

const setAdsInputValidationMessage = (input: ValidationControl, message = '') => {
  const existingErrorMessage = existingErrorForInput(input);
  const errorId = errorIdForInput(input, existingErrorMessage);
  const hasError = Boolean(message);

  input.setAttribute('aria-invalid', String(hasError));
  setInputDescribedBy(input, errorId, hasError);

  if (hasError) {
    const errorMessage = getOrCreateErrorMessage(input);
    if (errorMessage) {
      errorMessage.id = errorId;
      ensureErrorInner(errorMessage).textContent = message;
      errorMessage.classList.add(VISIBLE_ERROR_CLASS);
      errorMessage.classList.remove('display-none');
      errorMessage.hidden = false;
    }
  } else if (existingErrorMessage) {
    ensureErrorInner(existingErrorMessage).textContent = '';
    existingErrorMessage.classList.remove(VISIBLE_ERROR_CLASS);
    existingErrorMessage.hidden = true;
  }
};

const validationMessagesForInput = (input: ValidationControl): Record<string, string> => {
  const raw = input.closest('.ads-input')?.getAttribute('data-ads-validation-messages');
  if (!raw) {
    return {};
  }

  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
};

const validationMessageForInput = (input: ValidationControl) => {
  if (input.validity.valid) {
    return '';
  }

  const messages = validationMessagesForInput(input);
  const { validity } = input;
  const keys: (keyof ValidityState)[] = [
    'valueMissing',
    'typeMismatch',
    'patternMismatch',
    'badInput',
    'tooShort',
    'tooLong',
    'rangeUnderflow',
    'rangeOverflow',
    'stepMismatch',
  ];

  for (const key of keys) {
    if (validity[key] && messages[key]) {
      return messages[key];
    }
  }

  return input.validationMessage;
};

const invalidControls = (form: HTMLFormElement) =>
  Array.from(form.querySelectorAll<ValidationControl>(VALIDATION_CONTROL_SELECTOR)).filter(
    (control) => !control.validity.valid,
  );

const focusFirstInvalidControl = (form: HTMLFormElement) => {
  invalidControls(form)[0]?.focus();
};

const submitterSkipsValidation = (event: SubmitEvent) => {
  const { submitter } = event;

  return (
    (submitter instanceof HTMLButtonElement || submitter instanceof HTMLInputElement) &&
    submitter.formNoValidate
  );
};

const validateAdsInput = (input: ValidationControl, { focus = false } = {}) => {
  const message = validationMessageForInput(input);
  setAdsInputValidationMessage(input, message);

  if (message && focus && input.form) {
    focusFirstInvalidControl(input.form);
  }

  return !message;
};

const bindInputValidation = (input: ValidationControl) => {
  if (input.dataset[ADS_VALIDATION_READY] === 'true') {
    return;
  }

  input.dataset[ADS_VALIDATION_READY] = 'true';
  input.addEventListener('blur', () => validateAdsInput(input));
  // Clear stale errors while typing; full messages surface on blur / invalid.
  input.addEventListener('input', () => setAdsInputValidationMessage(input, ''));
  input.addEventListener('change', () => setAdsInputValidationMessage(input, ''));
  input.addEventListener('invalid', (event) => {
    event.preventDefault();
    validateAdsInput(input, { focus: true });
  });
};

const ADS_PASSWORD_MATCH_READY = 'adsPasswordMatchReady';

const namedPasswordControl = (form: HTMLFormElement, name: 'password' | 'password_confirmation') =>
  form.querySelector<HTMLInputElement>(
    `.ads-input--password .ads-input__control[name$="[${name}]"], .ads-input--password .ads-input__control[name="${name}"]`,
  );

/**
 * Mirror of lg-password-confirmation: only sets constraint validity.
 * Messaging/submit disabling come from generic ads-input + form-submitters.
 */
const bindPasswordMatchValidation = (form: HTMLFormElement) => {
  if (form.dataset[ADS_PASSWORD_MATCH_READY] === 'true') {
    return;
  }

  const password = namedPasswordControl(form, 'password');
  const confirmation = namedPasswordControl(form, 'password_confirmation');
  if (!password || !confirmation) {
    return;
  }

  form.dataset[ADS_PASSWORD_MATCH_READY] = 'true';

  const sync = () => {
    const mismatch =
      Boolean(password.value) &&
      Boolean(confirmation.value) &&
      password.value !== confirmation.value;
    const message = mismatch
      ? validationMessagesForInput(confirmation).customError ||
        confirmation.validationMessage
      : '';
    confirmation.setCustomValidity(message);
  };

  password.addEventListener('input', sync);
  confirmation.addEventListener('input', sync);
  sync();
};

const bindFormValidation = (form: HTMLFormElement) => {
  bindFormSubmitters(form);
  bindPasswordMatchValidation(form);

  if (form.dataset[ADS_FORM_VALIDATION_READY] === 'true') {
    return;
  }

  form.dataset[ADS_FORM_VALIDATION_READY] = 'true';
  form.noValidate = true;
  form.addEventListener('submit', (event) => {
    if (submitterSkipsValidation(event)) {
      return;
    }

    if (form.checkValidity()) {
      return;
    }

    event.preventDefault();
    focusFirstInvalidControl(form);
  });
};

export const enhanceInputValidation = (root: ParentNode = document) => {
  const controls = Array.from(
    root.querySelectorAll<ValidationControl>(VALIDATION_CONTROL_SELECTOR),
  );

  controls
    .filter((control) => control.classList.contains('ads-input__control'))
    .forEach(bindInputValidation);

  const forms = new Set<HTMLFormElement>();
  controls.forEach((control) => {
    if (control.form) {
      forms.add(control.form);
    }
  });
  forms.forEach(bindFormValidation);
};

export const normalizeInputErrors = (root: ParentNode = document) => {
  root.querySelectorAll<HTMLElement>('.ads-input__error').forEach((error) => {
    const inner = ensureErrorInner(error);
    const hasText = (inner.textContent?.trim().length ?? 0) > 0;
    error.classList.toggle(VISIBLE_ERROR_CLASS, hasText);
    if (!hasText) {
      inner.textContent = '';
    }
  });
};

enhancePhoneInputs();
enhancePasswordToggles();
normalizeInputErrors();
enhanceInputValidation();
