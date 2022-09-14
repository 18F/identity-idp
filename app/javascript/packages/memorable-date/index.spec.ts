import userEvent from '@testing-library/user-event';
import '@18f/identity-validated-field/validated-field-element';
import '.';
import { findByDisplayValue } from '@testing-library/dom';

const EXAMPLE_ERROR_MAPPINGS = {
  error_messages: {
    missing_month_day_year: 'Enter a date of birth',
    missing_month_day: 'Enter a month and day',
    missing_month_year: 'Enter a month and year',
    missing_day_year: 'Enter a day and year',
    missing_month: 'Enter a month',
    missing_day: 'Enter a day',
    missing_year: 'Enter a year',
    invalid_month: 'Enter a month between 1 and 12',
    invalid_day: 'Enter a day between 1 and 31',
    invalid_year: 'Enter a year with 4 numbers',
    invalid_date: 'The entry is not a valid date',
    range_underflow: 'Enter a date on or after September 02, 1822',
    range_overflow: 'Enter a date that is in the past',
    outside_date_range: 'Enter a Date of birth between September 02, 1822 and September 02, 2022',
  },
  range_errors: [],
};
const EXAMPLE_ERROR_MAPPINGS_WITH_RANGE_ERRORS = {
  error_messages: EXAMPLE_ERROR_MAPPINGS.error_messages,
  range_errors: [
    {
      message: 'Outside allowed total range',
      max: '1970-01-01',
      min: '1950-01-01',
    },
    {
      message: 'Must be in at least 1955',
      min: '1955-01-01',
    },
    {
      message: "The 1960's are off-limits!",
      max: '1960-01-01',
    },
    {
      message: "If you get an error about 1962, then something's not working",
      max: '1962-01-01',
    },
  ],
};

describe('MemorableDateElement', () => {
  let container;
  let formElement;
  let otherClickableElement;
  let memorableDateElement;
  let errorMessageMappingsElement;
  let errorMessageElement;
  let monthInput;
  let dayInput;
  let yearInput;
  let submitButton;

  function expectErrorToEqual(text: string) {
    if (errorMessageElement.style.display !== 'none') {
      expect(errorMessageElement.textContent).to.equal(text);
    } else {
      expect('').to.equal(text);
    }
  }

  beforeEach(() => {
    container = document.createElement('div');
    container.innerHTML = `
        <form id="test-md-form">
            <div id="test-md-extra-text">This is an arbitrary element to click</div>
            <lg-memorable-date id="test-memorable-date">
                <script id="test-md-error-mappings" type="application/json" class="memorable-date__error-strings"></script>
                <lg-validated-field>
                    <input type="text"
                        id="test-md-month"
                        required="required"
                        class="validated-field__input memorable-date__month"
                        aria-invalid="false"
                        aria-describedby="test-md-error-message"
                        pattern="(1[0-2])|(0?[1-9])"
                        minlength="1"
                        maxlength="2" />
                </lg-validated-field>
                <lg-validated-field>
                    <input type="text"
                        id="test-md-day"
                        required="required"
                        class="validated-field__input memorable-date__day"
                        aria-invalid="false"
                        aria-describedby="test-md-error-message"
                        pattern="(3[01])|([12][0-9])|(0?[1-9])"
                        minlength="1"
                        maxlength="2" />
                </lg-validated-field>
                <lg-validated-field>
                    <input type="text"
                        id="test-md-year"
                        required="required"
                        class="validated-field__input memorable-date__year"
                        aria-invalid="false"
                        aria-describedby="test-md-error-message"
                        pattern="\\d{4}"
                        minlength="4"
                        maxlength="4" />
                </lg-validated-field>
            </lg-memorable-date>
            <div id="test-md-error-message" class="usa-error-message" style="display:none;"></div>
            <button id="test-md-submit">Submit</button>
        </form>
        `;
    document.body.appendChild(container);

    formElement = document.getElementById('test-md-form');
    expect(formElement?.tagName).to.equal('FORM');

    otherClickableElement = document.getElementById('test-md-extra-text');
    expect(otherClickableElement?.tagName).to.equal('DIV');

    memorableDateElement = document.getElementById('test-memorable-date');
    expect(memorableDateElement?.tagName).to.equal('LG-MEMORABLE-DATE');

    errorMessageMappingsElement = document.getElementById('test-md-error-mappings');
    expect(errorMessageMappingsElement?.tagName).to.equal('SCRIPT');

    monthInput = document.getElementById('test-md-month');
    expect(monthInput?.tagName).to.equal('INPUT');

    dayInput = document.getElementById('test-md-day');
    expect(dayInput?.tagName).to.equal('INPUT');

    yearInput = document.getElementById('test-md-year');
    expect(yearInput?.tagName).to.equal('INPUT');

    errorMessageElement = document.getElementById('test-md-error-message');
    expect(errorMessageElement?.tagName).to.equal('DIV');

    submitButton = document.getElementById('test-md-submit');
    expect(submitButton?.tagName).to.equal('BUTTON');
    submitButton.addEventListener('click', (e: Event) => {
      e.preventDefault();
      formElement.reportValidity();
    });
  });

  afterEach(() => {
    container.remove();
    container = null;
    memorableDateElement = null;
    errorMessageMappingsElement = null;
    monthInput = null;
    dayInput = null;
    yearInput = null;
    errorMessageElement = null;
  });

  function itAcceptsAValidDate() {
    it('accepts valid date', async () => {
      await userEvent.type(monthInput, '12');
      await userEvent.type(dayInput, '5');
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('');
      expect(formElement.reportValidity()).to.be.true();
    });
  }

  // This is for a New Relic bug that overrides
  // the addEventListener and removeEventListener functions.
  // See here: https://discuss.newrelic.com/t/javascrypt-snippet-breaks-site/52188
  function itIsUnaffectedByNewRelicEventBug() {
    context(
      'another script overrides the addEventListener in a way that loses function identity',
      () => {
        let originalAddEventListenerFunction;
        beforeEach(() => {
          originalAddEventListenerFunction = Element.prototype.addEventListener;
          Element.prototype.addEventListener = function addEventListener(type, listener, ...args) {
            if (listener instanceof Function) {
              listener = function overrideListener(...eventArgs) {
                return listener.apply(this, eventArgs);
              };
            }

            if (arguments.length > 1) {
              args.unshift(listener);
            }

            if (arguments.length > 0) {
              args.unshift(type);
            }
            return originalAddEventListenerFunction.apply(this, args);
          };
        });

        afterEach(() => {
          Element.prototype.addEventListener = originalAddEventListenerFunction;
          originalAddEventListenerFunction = null;
        });

        context(
          'user has entered a day and year, then clicks an element outside the memorable date fields',
          () => {
            beforeEach(async function () {
              this.timeout(8000);

              await userEvent.click(dayInput);
              await userEvent.type(dayInput, '1');
              await userEvent.click(yearInput);
              await userEvent.type(yearInput, '19');
              await userEvent.click(otherClickableElement);

              // Issue seems to happen after a 5 or more second delay in this state
              await new Promise((resolve) => setTimeout(resolve, 6000));
            });

            it('does not hang when the user modifies the day', async () => {
              await userEvent.click(dayInput);
              await userEvent.type(dayInput, '5');
              const dayInputWithText = await findByDisplayValue(memorableDateElement, '15');
              expect(dayInputWithText.id).to.equal(dayInput.id);
            });

            it('does not hang when the user modifies the year', async () => {
              await userEvent.click(yearInput);
              await userEvent.type(yearInput, '4');
              const yearInputWithText = await findByDisplayValue(memorableDateElement, '194');
              expect(yearInputWithText.id).to.equal(yearInput.id);
            });
          },
        );
      },
    );
  }

  function itHidesValidationErrorsOnTyping() {
    it('hides validation errors on typing', async () => {
      const expectNoVisibleError = () => {
        expect(errorMessageElement).to.satisfy(
          (element: HTMLDivElement) => element.style.display === 'none' || !element.textContent,
        );
        expect(Array.from(monthInput.classList)).not.to.contain('usa-input--error');
        expect(monthInput.getAttribute('aria-invalid')).to.equal('false');
        expect(Array.from(dayInput.classList)).not.to.contain('usa-input--error');
        expect(dayInput.getAttribute('aria-invalid')).to.equal('false');
        expect(Array.from(yearInput.classList)).not.to.contain('usa-input--error');
        expect(yearInput.getAttribute('aria-invalid')).to.equal('false');
      };

      const expectVisibleError = () => {
        expect(errorMessageElement.style.display).not.to.equal('none');
        expect(errorMessageElement.textContent).not.to.be.empty();
        expect(Array.from(monthInput.classList)).to.contain('usa-input--error');
        expect(monthInput.getAttribute('aria-invalid')).to.equal('true');
        expect(Array.from(dayInput.classList)).to.contain('usa-input--error');
        expect(dayInput.getAttribute('aria-invalid')).to.equal('true');
        expect(Array.from(yearInput.classList)).to.contain('usa-input--error');
        expect(yearInput.getAttribute('aria-invalid')).to.equal('true');
      };

      expectNoVisibleError();

      submitButton.click();
      expectVisibleError();

      await userEvent.type(monthInput, 'a');
      expectNoVisibleError();

      submitButton.click();
      expectVisibleError();

      await userEvent.type(dayInput, 'a');
      expectNoVisibleError();

      submitButton.click();
      expectVisibleError();

      await userEvent.type(yearInput, 'a');
      expectNoVisibleError();

      submitButton.click();
      expectVisibleError();
    });
  }
  describe('error message mappings are empty', () => {
    itAcceptsAValidDate();
    itHidesValidationErrorsOnTyping();
    itIsUnaffectedByNewRelicEventBug();
    it('uses default required validation', async () => {
      expectErrorToEqual('');
      submitButton.click();
      expectErrorToEqual('Constraints not satisfied');

      await userEvent.clear(monthInput);
      await userEvent.type(dayInput, '5');
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Constraints not satisfied');
      expect(formElement.reportValidity()).to.be.false();

      await userEvent.type(monthInput, '12');
      await userEvent.clear(dayInput);
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Constraints not satisfied');
      expect(formElement.reportValidity()).to.be.false();

      await userEvent.type(monthInput, '12');
      await userEvent.type(dayInput, '5');
      await userEvent.clear(yearInput);
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Constraints not satisfied');
      expect(formElement.reportValidity()).to.be.false();
    });

    it('uses default pattern validation', async () => {
      await userEvent.clear(monthInput);
      await userEvent.type(monthInput, 'ab');
      await userEvent.type(dayInput, '5');
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Constraints not satisfied');
      expect(formElement.reportValidity()).to.be.false();

      await userEvent.clear(monthInput);
      await userEvent.type(monthInput, '12');
      await userEvent.clear(dayInput);
      await userEvent.type(dayInput, 'ab');
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Constraints not satisfied');
      expect(formElement.reportValidity()).to.be.false();

      await userEvent.type(monthInput, '12');
      await userEvent.clear(dayInput);
      await userEvent.type(dayInput, '5');
      await userEvent.clear(yearInput);
      await userEvent.type(yearInput, 'abcd');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Constraints not satisfied');
      expect(formElement.reportValidity()).to.be.false();
    });
  });

  describe('error message mappings are not empty', () => {
    beforeEach(() => {
      errorMessageMappingsElement.textContent = JSON.stringify(EXAMPLE_ERROR_MAPPINGS);
    });
    afterEach(() => {
      errorMessageMappingsElement.textContent = '';
    });
    itAcceptsAValidDate();
    itHidesValidationErrorsOnTyping();
    itIsUnaffectedByNewRelicEventBug();
    it('uses customized messages for required validation', async () => {
      expectErrorToEqual('');
      submitButton.click();
      expectErrorToEqual('Enter a date of birth');

      await userEvent.type(dayInput, '5');
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a month');
      expect(formElement.reportValidity()).to.be.false();

      await userEvent.type(monthInput, '12');
      await userEvent.clear(dayInput);
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a day');
      expect(formElement.reportValidity()).to.be.false();

      await userEvent.type(monthInput, '12');
      await userEvent.type(dayInput, '5');
      await userEvent.clear(yearInput);
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a year');
      expect(formElement.reportValidity()).to.be.false();
    });

    it('uses customized messages for pattern validation', async () => {
      await userEvent.type(monthInput, 'ab');
      await userEvent.type(dayInput, '5');
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a month between 1 and 12');
      expect(formElement.reportValidity()).to.be.false();

      await userEvent.clear(monthInput);
      await userEvent.type(monthInput, '12');
      await userEvent.clear(dayInput);
      await userEvent.type(dayInput, 'ab');
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a day between 1 and 31');
      expect(formElement.reportValidity()).to.be.false();

      await userEvent.type(monthInput, '12');
      await userEvent.clear(dayInput);
      await userEvent.type(dayInput, '5');
      await userEvent.clear(yearInput);
      await userEvent.type(yearInput, 'abcd');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a year with 4 numbers');
      expect(formElement.reportValidity()).to.be.false();
    });

    it('uses customized messages for invalid date validation', async () => {
      await userEvent.type(monthInput, '2');
      await userEvent.type(dayInput, '30');
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('The entry is not a valid date');
      expect(formElement.reportValidity()).to.be.false();
    });

    it('does not show error styles on fields unrelated to the validation message', async () => {
      await userEvent.type(monthInput, '2');
      await userEvent.type(yearInput, '1972');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a day');
      expect(formElement.reportValidity()).to.be.false();
      expect(Array.from(monthInput.classList)).to.not.include('usa-input--error');
      expect(Array.from(dayInput.classList)).to.include('usa-input--error');
      expect(Array.from(yearInput.classList)).to.not.include('usa-input--error');

      await userEvent.type(dayInput, 'bc');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a day between 1 and 31');
      expect(formElement.reportValidity()).to.be.false();
      expect(Array.from(monthInput.classList)).to.not.include('usa-input--error');
      expect(Array.from(dayInput.classList)).to.include('usa-input--error');
      expect(Array.from(yearInput.classList)).to.not.include('usa-input--error');

      await userEvent.type(monthInput, 'z');
      await userEvent.clear(dayInput);
      await userEvent.type(dayInput, '18');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a month between 1 and 12');
      expect(formElement.reportValidity()).to.be.false();
      expect(Array.from(monthInput.classList)).to.include('usa-input--error');
      expect(Array.from(dayInput.classList)).to.not.include('usa-input--error');
      expect(Array.from(yearInput.classList)).to.not.include('usa-input--error');

      await userEvent.clear(monthInput);
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a month');
      expect(formElement.reportValidity()).to.be.false();
      expect(Array.from(monthInput.classList)).to.include('usa-input--error');
      expect(Array.from(dayInput.classList)).to.not.include('usa-input--error');
      expect(Array.from(yearInput.classList)).to.not.include('usa-input--error');

      await userEvent.type(monthInput, '4');
      await userEvent.clear(yearInput);
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a year');
      expect(formElement.reportValidity()).to.be.false();
      expect(Array.from(monthInput.classList)).to.not.include('usa-input--error');
      expect(Array.from(dayInput.classList)).to.not.include('usa-input--error');
      expect(Array.from(yearInput.classList)).to.include('usa-input--error');

      await userEvent.type(yearInput, '1');
      expectErrorToEqual('');
      await userEvent.click(submitButton);
      expectErrorToEqual('Enter a year with 4 numbers');
      expect(formElement.reportValidity()).to.be.false();
      expect(Array.from(monthInput.classList)).to.not.include('usa-input--error');
      expect(Array.from(dayInput.classList)).to.not.include('usa-input--error');
      expect(Array.from(yearInput.classList)).to.include('usa-input--error');
    });

    describe('min and max are set on lg-memorable-date', () => {
      beforeEach(() => {
        memorableDateElement.setAttribute('min', '1800-01-01');
        memorableDateElement.setAttribute('max', '2100-01-01');
      });
      afterEach(() => {
        memorableDateElement.removeAttribute('min');
        memorableDateElement.removeAttribute('max');
      });
      it('uses customized messages for min validation', async () => {
        await userEvent.type(monthInput, '12');
        await userEvent.type(dayInput, '31');
        await userEvent.type(yearInput, '1799');
        expectErrorToEqual('');
        await userEvent.click(submitButton);
        expectErrorToEqual('Enter a date on or after September 02, 1822');
        expect(formElement.reportValidity()).to.be.false();
      });
      it('uses customized message for max validation', async () => {
        await userEvent.type(monthInput, '1');
        await userEvent.type(dayInput, '2');
        await userEvent.type(yearInput, '2100');
        expectErrorToEqual('');
        await userEvent.click(submitButton);
        expectErrorToEqual('Enter a date that is in the past');
        expect(formElement.reportValidity()).to.be.false();
      });
      it('accepts a date within the specified range', async () => {
        await userEvent.type(monthInput, '1');
        await userEvent.type(dayInput, '5');
        await userEvent.type(yearInput, '1918');
        expectErrorToEqual('');
        await userEvent.click(submitButton);
        expectErrorToEqual('');
        expect(formElement.reportValidity()).to.be.true();
      });
    });
    describe('error mappings include custom min and max ranges with different messages', () => {
      beforeEach(() => {
        errorMessageMappingsElement.textContent = JSON.stringify(
          EXAMPLE_ERROR_MAPPINGS_WITH_RANGE_ERRORS,
        );
      });
      afterEach(() => {
        errorMessageMappingsElement.textContent = '';
      });
      it('accepts a date within all specified ranges', async () => {
        await userEvent.type(monthInput, '4');
        await userEvent.type(dayInput, '15');
        await userEvent.type(yearInput, '1957');
        expectErrorToEqual('');
        await userEvent.click(submitButton);
        expectErrorToEqual('');
        expect(formElement.reportValidity()).to.be.true();
      });
      it('applies max in 2-sided date range validation', async () => {
        await userEvent.type(monthInput, '8');
        await userEvent.type(dayInput, '15');
        await userEvent.type(yearInput, '1971');
        expectErrorToEqual('');
        await userEvent.click(submitButton);
        expectErrorToEqual('Outside allowed total range');
        expect(formElement.reportValidity()).to.be.false();
      });
      it('applies min in 2-sided date range validation', async () => {
        await userEvent.type(monthInput, '2');
        await userEvent.type(dayInput, '13');
        await userEvent.type(yearInput, '1943');
        expectErrorToEqual('');
        await userEvent.click(submitButton);
        expectErrorToEqual('Outside allowed total range');
        expect(formElement.reportValidity()).to.be.false();
      });
      it('applies max date validation', async () => {
        await userEvent.type(monthInput, '3');
        await userEvent.type(dayInput, '15');
        await userEvent.type(yearInput, '1961');
        expectErrorToEqual('');
        await userEvent.click(submitButton);
        expectErrorToEqual("The 1960's are off-limits!");
        expect(formElement.reportValidity()).to.be.false();
      });
      it('applies min date validation', async () => {
        await userEvent.type(monthInput, '6');
        await userEvent.type(dayInput, '4');
        await userEvent.type(yearInput, '1953');
        expectErrorToEqual('');
        await userEvent.click(submitButton);
        expectErrorToEqual('Must be in at least 1955');
        expect(formElement.reportValidity()).to.be.false();
      });
      it('applies validation for ranges in provided order', async () => {
        await userEvent.type(monthInput, '9');
        await userEvent.type(dayInput, '23');
        await userEvent.type(yearInput, '1963');
        expectErrorToEqual('');
        await userEvent.click(submitButton);
        expectErrorToEqual("The 1960's are off-limits!");
        expect(formElement.reportValidity()).to.be.false();
      });
    });
  });
});
