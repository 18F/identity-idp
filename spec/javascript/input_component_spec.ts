import {
  enhanceInputValidation,
  enhancePasswordToggles,
  enhancePhoneInputs,
} from '../../app/components/input_component';

describe('InputComponent phone formatting', () => {
  const renderPhoneInput = ({
    country = 'US',
    value = '',
    countrySelector = false,
  }: {
    country?: string;
    value?: string;
    countrySelector?: boolean;
  } = {}) => {
    document.body.innerHTML = `
      <div class="ads-input${countrySelector ? ' ads-input--phone' : ''}">
        ${
          countrySelector
            ? `<div class="ads-input__country-shell">
                <span data-ads-phone-country-value></span>
                <select data-ads-phone-country>
                  <option value="US" data-dial-code="+1">United States (+1)</option>
                  <option value="GB" data-dial-code="+44">United Kingdom (+44)</option>
                </select>
              </div>`
            : ''
        }
        <input data-ads-phone-input type="tel">
      </div>
    `;

    const select = document.querySelector('select');
    const input = document.querySelector('input')!;
    if (select) {
      select.value = country;
    }
    input.value = value;
    enhancePhoneInputs();

    return { input, select };
  };

  const type = (input: HTMLInputElement, value: string) => {
    input.focus();
    for (const character of value) {
      const start = input.selectionStart ?? input.value.length;
      const end = input.selectionEnd ?? start;
      input.setRangeText(character, start, end, 'end');
      input.dispatchEvent(new InputEvent('input', { bubbles: true, data: character }));
    }
  };

  it('formats national US numbers without a country selector', () => {
    const { input, select } = renderPhoneInput();
    type(input, '2025550199');
    expect(input.value).to.equal('(202) 555-0199');
    expect(select).to.be.null();
  });

  it('formats international US numbers without a country selector', () => {
    const { input } = renderPhoneInput();
    type(input, '+12025550199');
    expect(input.value).to.equal('+1 202 555 0199');
  });

  it('formats numbers using the selected country', () => {
    const { input, select } = renderPhoneInput({ countrySelector: true });
    select!.value = 'GB';
    select!.dispatchEvent(new Event('change', { bubbles: true }));
    type(input, '02079460018');
    expect(input.value).to.equal('020 7946 0018');
  });

  it('reformats for country changes and updates the collapsed dial code', () => {
    const { input, select } = renderPhoneInput({
      countrySelector: true,
      country: 'US',
      value: '2025550199',
    });
    expect(input.value).to.equal('(202) 555-0199');

    select!.value = 'GB';
    select!.dispatchEvent(new Event('change', { bubbles: true }));

    expect(input.value).to.equal('2025550199');
    expect(document.querySelector('[data-ads-phone-country-value]')?.textContent).to.equal('+44');
  });

  it('preserves the caret through mid-string edits and backspace', () => {
    const { input } = renderPhoneInput({ value: '2025550199' });
    input.focus();
    input.setSelectionRange(2, 3);
    input.setRangeText('9', 2, 3, 'end');
    input.dispatchEvent(new InputEvent('input', { bubbles: true, data: '9' }));

    expect(input.value).to.equal('(292) 555-0199');
    expect(input.selectionStart).to.equal(3);

    input.value = '(202) 555-0199';
    input.setSelectionRange(8, 8);
    input.setRangeText('', 7, 8, 'end');
    input.dispatchEvent(
      new InputEvent('input', { bubbles: true, inputType: 'deleteContentBackward' }),
    );

    expect(input.value).to.equal('(202) 550-199');
    expect(input.selectionStart).to.equal(7);
  });
});

describe('InputComponent password toggle', () => {
  const renderPasswordInput = () => {
    const inputId = 'preview_password';
    document.body.innerHTML = `
      <div class="ads-input ads-input--password">
        <label class="ads-input__label" for="${inputId}">Password</label>
        <div class="ads-input__shell">
          <input id="${inputId}" type="password" class="ads-input__control ads-input__control--password">
          <button
            type="button"
            class="ads-input__toggle"
            data-ads-password-toggle
            data-label-show="Show password"
            data-label-hide="Hide password"
            aria-controls="${inputId}"
            aria-label="Show password"
            aria-pressed="false"
          >
            <svg data-ads-password-icon-show aria-hidden="true"></svg>
            <svg data-ads-password-icon-hide hidden aria-hidden="true"></svg>
          </button>
        </div>
      </div>
    `;

    enhancePasswordToggles();

    return {
      input: document.querySelector('input')!,
      button: document.querySelector('button')!,
    };
  };

  it('toggles input visibility and accessible state', () => {
    const { input, button } = renderPasswordInput();

    expect(input.type).to.equal('password');
    expect(button.getAttribute('aria-pressed')).to.equal('false');
    expect(button.getAttribute('aria-label')).to.equal('Show password');

    button.click();

    expect(input.type).to.equal('text');
    expect(button.getAttribute('aria-pressed')).to.equal('true');
    expect(button.getAttribute('aria-label')).to.equal('Hide password');

    button.click();

    expect(input.type).to.equal('password');
    expect(button.getAttribute('aria-pressed')).to.equal('false');
  });

  it('keeps the input focused when the toggle is pressed with a pointer', () => {
    const { input, button } = renderPasswordInput();
    input.focus();
    expect(document.activeElement).to.equal(input);

    button.dispatchEvent(
      new MouseEvent('mousedown', { bubbles: true, cancelable: true, button: 0 }),
    );
    button.click();

    expect(input.type).to.equal('text');
    expect(document.activeElement).to.equal(input);
  });

  it('returns focus to the input after keyboard activation of the toggle', () => {
    const { input, button } = renderPasswordInput();
    button.focus();
    expect(document.activeElement).to.equal(button);

    button.click();

    expect(input.type).to.equal('text');
    expect(document.activeElement).to.equal(input);
  });

  it('syncs visibility for password and confirmation toggles in the same form', () => {
    document.body.innerHTML = `
      <form>
        <div class="ads-input ads-input--password">
          <div class="ads-input__shell">
            <input id="password" type="password" class="ads-input__control">
            <button
              type="button"
              data-ads-password-toggle
              data-label-show="Show password"
              data-label-hide="Hide password"
              aria-controls="password"
              aria-label="Show password"
              aria-pressed="false"
            >
              <svg data-ads-password-icon-show></svg>
              <svg data-ads-password-icon-hide hidden></svg>
            </button>
          </div>
        </div>
        <div class="ads-input ads-input--password">
          <div class="ads-input__shell">
            <input id="password_confirmation" type="password" class="ads-input__control">
            <button
              type="button"
              data-ads-password-toggle
              data-label-show="Show password"
              data-label-hide="Hide password"
              aria-controls="password_confirmation"
              aria-label="Show password"
              aria-pressed="false"
            >
              <svg data-ads-password-icon-show></svg>
              <svg data-ads-password-icon-hide hidden></svg>
            </button>
          </div>
        </div>
      </form>
    `;

    enhancePasswordToggles();

    const password = document.getElementById('password') as HTMLInputElement;
    const confirmation = document.getElementById(
      'password_confirmation',
    ) as HTMLInputElement;
    const [passwordToggle, confirmationToggle] = Array.from(
      document.querySelectorAll<HTMLButtonElement>('[data-ads-password-toggle]'),
    );

    passwordToggle.click();

    expect(password.type).to.equal('text');
    expect(confirmation.type).to.equal('text');
    expect(passwordToggle.getAttribute('aria-pressed')).to.equal('true');
    expect(confirmationToggle.getAttribute('aria-pressed')).to.equal('true');

    confirmationToggle.click();

    expect(password.type).to.equal('password');
    expect(confirmation.type).to.equal('password');
    expect(passwordToggle.getAttribute('aria-pressed')).to.equal('false');
    expect(confirmationToggle.getAttribute('aria-pressed')).to.equal('false');
  });
});

describe('InputComponent validation', () => {
  const emailMessages = {
    valueMissing: 'Enter a valid email',
    typeMismatch: 'Enter a valid email',
  };

  const renderRequiredInput = ({ withHint = false } = {}) => {
    document.body.innerHTML = `
      <form>
        <div
          class="ads-input"
          data-ads-validation-messages='${JSON.stringify(emailMessages)}'
        >
          <label class="ads-input__label" for="user_email">Email</label>
          <div class="ads-input__shell">
            <input
              id="user_email"
              name="user[email]"
              type="email"
              required
              class="ads-input__control"
            >
          </div>
          ${withHint ? '<p class="ads-input__hint" id="user_email_hint">Use your email.</p>' : ''}
        </div>
      </form>
    `;

    const input = document.querySelector<HTMLInputElement>('.ads-input__control')!;
    enhanceInputValidation();

    return { input, form: document.querySelector('form')! };
  };

  it('shows the ADS error message on blur', () => {
    const { input } = renderRequiredInput();

    input.dispatchEvent(new FocusEvent('blur'));

    const errorMessage = document.querySelector<HTMLElement>('.ads-input__error')!;
    const errorInner = errorMessage.querySelector<HTMLElement>('.ads-input__error-inner')!;
    expect(input.getAttribute('aria-invalid')).to.equal('true');
    expect(input.getAttribute('aria-describedby')).to.equal('user_email_ads_error');
    expect(errorMessage.id).to.equal('user_email_ads_error');
    expect(errorMessage.classList.contains('ads-input__error--visible')).to.equal(true);
    expect(errorInner.textContent).to.equal('Enter a valid email');
  });

  it('shows a type-specific message for invalid email values', () => {
    const { input } = renderRequiredInput();
    input.value = 'not-an-email';

    input.dispatchEvent(new FocusEvent('blur'));

    expect(document.querySelector('.ads-input__error-inner')?.textContent).to.equal(
      'Enter a valid email',
    );
  });

  it('uses custom required messages from data-ads-validation-messages', () => {
    document.body.innerHTML = `
      <form>
        <div
          class="ads-input"
          data-ads-validation-messages='${JSON.stringify({
            valueMissing: 'Enter a nickname',
          })}'
        >
          <label class="ads-input__label" for="nickname">Key nickname</label>
          <div class="ads-input__shell">
            <input
              id="nickname"
              name="name"
              type="text"
              required
              class="ads-input__control"
            >
          </div>
        </div>
      </form>
    `;

    const input = document.querySelector<HTMLInputElement>('.ads-input__control')!;
    enhanceInputValidation();
    input.dispatchEvent(new FocusEvent('blur'));

    expect(document.querySelector('.ads-input__error-inner')?.textContent).to.equal(
      'Enter a nickname',
    );
  });

  it('inserts the ADS error message below the input shell', () => {
    const { input } = renderRequiredInput({ withHint: true });

    input.dispatchEvent(new FocusEvent('blur'));

    const inputShell = document.querySelector('.ads-input__shell')!;
    expect(inputShell.nextElementSibling?.classList.contains('ads-input__error')).to.equal(true);
  });

  it('suppresses native validation UI and focuses the first invalid ADS input', () => {
    const { input } = renderRequiredInput();

    const event = new Event('invalid', { cancelable: true });
    const defaultWasNotPrevented = input.dispatchEvent(event);

    expect(defaultWasNotPrevented).to.equal(false);
    expect(input.getAttribute('aria-invalid')).to.equal('true');
    expect(document.activeElement).to.equal(input);
  });

  it('clears the ADS error message while editing', () => {
    const { input } = renderRequiredInput();

    input.dispatchEvent(new FocusEvent('blur'));
    input.value = 'person@example.com';
    input.dispatchEvent(new InputEvent('input', { bubbles: true }));

    const errorMessage = document.querySelector<HTMLElement>('.ads-input__error')!;
    expect(input.getAttribute('aria-invalid')).to.equal('false');
    expect(input.getAttribute('aria-describedby')).to.be.null();
    expect(errorMessage.classList.contains('ads-input__error--visible')).to.equal(false);
    expect(errorMessage.querySelector('.ads-input__error-inner')?.textContent).to.equal('');
  });

  it('validates ADS inputs on submit without native validation UI', () => {
    const { form, input } = renderRequiredInput();
    enhanceInputValidation();

    const event = new SubmitEvent('submit', { cancelable: true });
    const defaultWasNotPrevented = form.dispatchEvent(event);

    expect(form.noValidate).to.equal(true);
    expect(defaultWasNotPrevented).to.equal(false);
    expect(input.getAttribute('aria-invalid')).to.equal('true');
    expect(document.activeElement).to.equal(input);
    expect(document.querySelector('.ads-input__error.ads-input__error--visible')).to.exist();
  });

  it('does not validate submitters that opt out of form validation', () => {
    const { form, input } = renderRequiredInput();
    const button = document.createElement('button');
    button.type = 'submit';
    button.formNoValidate = true;
    form.appendChild(button);

    const event = new SubmitEvent('submit', { cancelable: true, submitter: button });
    const defaultWasNotPrevented = form.dispatchEvent(event);

    expect(defaultWasNotPrevented).to.equal(true);
    expect(input.getAttribute('aria-invalid')).to.be.null();
    expect(document.querySelector('.ads-input__error.ads-input__error--visible')).not.to.exist();
  });

  it('validates ADS selects on blur', () => {
    document.body.innerHTML = `
      <form>
        <div class="ads-input">
          <label class="ads-input__label" for="user_state">State</label>
          <div class="ads-input__shell">
            <select id="user_state" name="user[state]" required class="ads-input__control">
              <option value=""></option>
              <option value="CA">California</option>
            </select>
          </div>
        </div>
      </form>
    `;

    const select = document.querySelector<HTMLSelectElement>('.ads-input__control')!;
    enhanceInputValidation();
    select.dispatchEvent(new FocusEvent('blur'));

    expect(select.getAttribute('aria-invalid')).to.equal('true');
    expect(document.querySelector('.ads-input__error.ads-input__error--visible')).to.exist();
  });

  it('disables the submit button until required fields are valid', () => {
    document.body.innerHTML = `
      <form>
        <div
          class="ads-input"
          data-ads-validation-messages='${JSON.stringify(emailMessages)}'
        >
          <label class="ads-input__label" for="user_email">Email</label>
          <div class="ads-input__shell">
            <input
              id="user_email"
              name="user[email]"
              type="email"
              required
              class="ads-input__control"
            >
          </div>
        </div>
        <button type="submit">Continue</button>
      </form>
    `;

    const input = document.querySelector<HTMLInputElement>('.ads-input__control')!;
    const button = document.querySelector<HTMLButtonElement>('button[type="submit"]')!;
    enhanceInputValidation();

    expect(button.disabled).to.equal(true);

    input.value = 'not-an-email';
    input.dispatchEvent(new InputEvent('input', { bubbles: true }));
    expect(button.disabled).to.equal(true);

    input.value = 'person@example.com';
    input.dispatchEvent(new InputEvent('input', { bubbles: true }));
    expect(button.disabled).to.equal(false);

    input.value = '';
    input.dispatchEvent(new InputEvent('input', { bubbles: true }));
    expect(button.disabled).to.equal(true);
  });

  it('leaves formNoValidate submitters enabled', () => {
    document.body.innerHTML = `
      <form>
        <div class="ads-input">
          <div class="ads-input__shell">
            <input type="email" required class="ads-input__control">
          </div>
        </div>
        <button type="submit">Continue</button>
        <button type="submit" formnovalidate>Skip</button>
      </form>
    `;

    enhanceInputValidation();
    const [continueButton, skipButton] = document.querySelectorAll<HTMLButtonElement>(
      'button[type="submit"]',
    );

    expect(continueButton.disabled).to.equal(true);
    expect(skipButton.disabled).to.equal(false);
  });

  const mismatchMessages = {
    customError: 'Your passwords don’t match',
    valueMissing: 'Enter a password',
  };

  const renderPasswordPairForm = () => {
    document.body.innerHTML = `
      <form>
        <div class="ads-input ads-input--password">
          <div class="ads-input__shell">
            <input
              id="password"
              name="password_form[password]"
              type="password"
              required
              class="ads-input__control ads-input__control--password"
            >
          </div>
          <p class="ads-input__error" data-ads-error>
            <span class="ads-input__error-inner"></span>
          </p>
        </div>
        <div
          class="ads-input ads-input--password"
          data-ads-validation-messages='${JSON.stringify(mismatchMessages)}'
        >
          <div class="ads-input__shell">
            <input
              id="password_form_password_confirmation"
              name="password_form[password_confirmation]"
              type="password"
              required
              class="ads-input__control ads-input__control--password"
            >
          </div>
          <p class="ads-input__error" data-ads-error>
            <span class="ads-input__error-inner"></span>
          </p>
        </div>
        <button type="submit">Continue</button>
      </form>
    `;

    enhanceInputValidation();

    return {
      password: document.getElementById('password') as HTMLInputElement,
      confirmation: document.getElementById(
        'password_form_password_confirmation',
      ) as HTMLInputElement,
      button: document.querySelector<HTMLButtonElement>('button[type="submit"]')!,
      confirmationError: document.querySelectorAll<HTMLElement>('.ads-input__error')[1],
    };
  };

  it('shows password mismatch on confirmation blur via constraint validation', () => {
    const { password, confirmation, confirmationError } = renderPasswordPairForm();

    password.value = 'correct-horse-battery';
    password.dispatchEvent(new InputEvent('input', { bubbles: true }));
    confirmation.value = 'correct-horse-batter';
    confirmation.dispatchEvent(new InputEvent('input', { bubbles: true }));

    // Errors clear on input; mismatch is a constraint until blur surfaces it.
    expect(confirmation.validity.customError).to.equal(true);
    expect(confirmationError.classList.contains('ads-input__error--visible')).to.equal(false);

    confirmation.dispatchEvent(new FocusEvent('blur'));

    expect(confirmationError.classList.contains('ads-input__error--visible')).to.equal(true);
    expect(confirmationError.textContent).to.include('Your passwords don’t match');
  });

  it('keeps Continue disabled until passwords match', () => {
    const { password, confirmation, button } = renderPasswordPairForm();

    expect(button.disabled).to.equal(true);

    password.value = 'correct-horse-battery';
    password.dispatchEvent(new InputEvent('input', { bubbles: true }));
    expect(button.disabled).to.equal(true);

    confirmation.value = 'correct-horse-batter';
    confirmation.dispatchEvent(new InputEvent('input', { bubbles: true }));
    expect(button.disabled).to.equal(true);
    expect(confirmation.validity.valid).to.equal(false);

    confirmation.value = 'correct-horse-battery';
    confirmation.dispatchEvent(new InputEvent('input', { bubbles: true }));
    expect(button.disabled).to.equal(false);
    expect(confirmation.validity.valid).to.equal(true);
  });
});
