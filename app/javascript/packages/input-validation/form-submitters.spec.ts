import userEvent from '@testing-library/user-event';
import '@18f/identity-validated-field/validated-field-element';
import '@18f/identity-memorable-date';
import { bindFormSubmitters } from './form-submitters';

describe('bindFormSubmitters', () => {
  context('with a memorable date', () => {
    const errorMappings = {
      error_messages: {
        missing_month_day_year: 'Enter a date of birth',
        missing_day_year: 'Enter a day and year',
        invalid_month: 'Enter a month between 1 and 12',
        invalid_day: 'Enter a day between 1 and 31',
        invalid_year: 'Enter a year with 4 numbers',
        invalid_date: 'The entry is not a valid date',
        range_overflow: 'Enter a date that is in the past',
      },
      range_errors: [{ max: '2008-01-01', message: 'You must be at least 18 years old' }],
    };

    const dateInput = (part: string, pattern: string, value = '') => `
      <lg-validated-field error-id="dob-error">
        <input
          type="text"
          id="dob-${part}"
          required
          class="validated-field__input memorable-date__${part}"
          aria-invalid="false"
          aria-describedby="dob-error"
          pattern="${pattern}"
          value="${value}"
        >
      </lg-validated-field>
    `;

    const renderForm = ({ month = '', day = '', year = '' } = {}) => {
      document.body.innerHTML = `
        <form>
          <lg-memorable-date max="2026-01-01">
            <script type="application/json" class="memorable-date__error-strings">
              ${JSON.stringify(errorMappings)}
            </script>
            ${dateInput('month', '(1[0-2])|(0?[1-9])', month)}
            ${dateInput('day', '(3[01])|([12][0-9])|(0?[1-9])', day)}
            ${dateInput('year', '\\d{4}', year)}
          </lg-memorable-date>
          <div id="dob-error" class="usa-error-message display-none"></div>
          <input id="after" type="text">
          <button type="submit">Continue</button>
        </form>
      `;

      const form = document.querySelector('form')!;
      bindFormSubmitters(form);

      return {
        month: document.getElementById('dob-month') as HTMLInputElement,
        day: document.getElementById('dob-day') as HTMLInputElement,
        year: document.getElementById('dob-year') as HTMLInputElement,
        after: document.getElementById('after') as HTMLInputElement,
        error: document.getElementById('dob-error')!,
        button: document.querySelector<HTMLButtonElement>('button[type="submit"]')!,
      };
    };

    const enterDate = async (
      { month, day, year }: Record<'month' | 'day' | 'year', HTMLInputElement>,
      [monthValue, dayValue, yearValue]: [string, string, string],
    ) => {
      await userEvent.type(month, monthValue);
      await userEvent.type(day, dayValue);
      await userEvent.type(year, yearValue);
    };

    afterEach(() => {
      document.body.innerHTML = '';
    });

    it('shows an invalid month error once focus leaves the date', async () => {
      const fields = renderForm();
      const { month, day, year, error, button } = fields;

      await enterDate(fields, ['13', '40', '2030']);
      expect(error.classList.contains('display-none')).to.equal(true);

      await userEvent.tab();

      expect(button.disabled).to.equal(true);
      expect(error.textContent).to.equal('Enter a month between 1 and 12');
      expect(error.classList.contains('display-none')).to.equal(false);
      expect(error.getAttribute('aria-live')).to.equal('polite');
      expect(month.getAttribute('aria-invalid')).to.equal('true');
      expect(month.getAttribute('aria-describedby')).to.equal('dob-error');
      expect(day.getAttribute('aria-invalid')).to.equal('true');
      expect(year.getAttribute('aria-invalid')).to.equal('false');
    });

    it('shows a range error once focus leaves the date', async () => {
      const fields = renderForm();
      const { month, day, year, error, button } = fields;

      await enterDate(fields, ['1', '15', '2015']);
      await userEvent.tab();

      expect(button.disabled).to.equal(true);
      expect(error.textContent).to.equal('You must be at least 18 years old');
      expect(error.classList.contains('display-none')).to.equal(false);
      [month, day, year].forEach((input) => {
        expect(input.getAttribute('aria-invalid')).to.equal('true');
        expect(input.getAttribute('aria-describedby')).to.equal('dob-error');
      });
    });

    it('does not show an error while moving between parts of the date', async () => {
      const { month, error } = renderForm();

      await userEvent.type(month, '13');
      await userEvent.tab();

      expect(error.classList.contains('display-none')).to.equal(true);
      expect(month.getAttribute('aria-invalid')).to.equal('false');
    });

    it('does not show an error when focus leaves an untouched empty date', async () => {
      const { month, after, error } = renderForm();

      await userEvent.click(month);
      await userEvent.click(after);

      expect(document.activeElement).to.equal(after);
      expect(error.classList.contains('display-none')).to.equal(true);
      expect(month.getAttribute('aria-invalid')).to.equal('false');
    });

    it('shows an error when focus leaves an untouched pre-filled invalid date', async () => {
      const { month, after, error, button } = renderForm({ month: '1', day: '15', year: '2015' });

      await userEvent.click(month);
      await userEvent.click(after);

      expect(button.disabled).to.equal(true);
      expect(error.textContent).to.equal('You must be at least 18 years old');
      expect(error.classList.contains('display-none')).to.equal(false);
      expect(month.getAttribute('aria-invalid')).to.equal('true');
    });

    it('shows a missing part error once focus leaves an edited date', async () => {
      const { month, day, after, error } = renderForm();

      await userEvent.type(month, '1');
      await userEvent.click(after);

      expect(error.textContent).to.equal('Enter a day and year');
      expect(error.classList.contains('display-none')).to.equal(false);
      expect(day.getAttribute('aria-invalid')).to.equal('true');
    });

    it('shows a missing date error on submit for an untouched date', () => {
      const { month, error } = renderForm();

      month.form!.checkValidity();

      expect(error.textContent).to.equal('Enter a date of birth');
      expect(error.classList.contains('display-none')).to.equal(false);
      expect(month.getAttribute('aria-invalid')).to.equal('true');
    });

    it('shows the error when focus leaves for a disabled submit button', async () => {
      const fields = renderForm();
      const { month, year, error, button } = fields;

      await enterDate(fields, ['13', '40', '2030']);
      button.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
      year.dispatchEvent(new FocusEvent('focusout', { bubbles: true }));

      expect(error.textContent).to.equal('Enter a month between 1 and 12');
      expect(error.classList.contains('display-none')).to.equal(false);
      expect(month.getAttribute('aria-invalid')).to.equal('true');
    });

    it('clears the error when the date is edited', async () => {
      const fields = renderForm();
      const { month, error } = fields;

      await enterDate(fields, ['13', '40', '2030']);
      await userEvent.tab();
      expect(error.classList.contains('display-none')).to.equal(false);
      await userEvent.type(month, '{Backspace}');

      expect(error.classList.contains('display-none')).to.equal(true);
      expect(month.getAttribute('aria-invalid')).to.equal('false');
    });

    it('enables the submit button without an error for a valid date', async () => {
      const fields = renderForm();
      const { month, error, button } = fields;

      await enterDate(fields, ['1', '15', '1990']);
      await userEvent.tab();

      expect(button.disabled).to.equal(false);
      expect(error.classList.contains('display-none')).to.equal(true);
      expect(month.getAttribute('aria-invalid')).to.equal('false');
    });
  });
});
