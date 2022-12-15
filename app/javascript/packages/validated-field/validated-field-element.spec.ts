import sinon from 'sinon';
import { getByRole, getByText } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import './validated-field-element';

describe('ValidatedFieldElement', () => {
  let idCounter = 0;

  function createAndConnectElement({ hasInitialError = false, errorInsideField = true } = {}) {
    const element = document.createElement('lg-validated-field');
    const errorMessageId = `validated-field-error-${++idCounter}`;
    element.setAttribute('error-id', errorMessageId);
    const errorHtml =
      hasInitialError || !errorInsideField
        ? `<div class="usa-error-message display-none" id="${errorMessageId}">${
            hasInitialError ? 'Invalid value' : ''
          }</div>`
        : '';
    element.innerHTML = `
      <script type="application/json" class="validated-field__error-strings">
        {
          "valueMissing": "This field is required"
        }
      </script>
      <div class="validated-field__input-wrapper">
        <label for="zipcode">ZIP code</label>
        <span id="validated-field-hint">Required Field</span>
        <input
          aria-invalid="false"
          aria-describedby="validated-field-hint${hasInitialError ? ` ${errorMessageId}` : ''}"
          required="required"
          aria-required="true"
          class="validated-field__input${hasInitialError ? ' usa-input--error' : ''}"
        />
        ${errorHtml && errorInsideField ? errorHtml : ''}
      </div>
    `;

    const form = document.querySelector('form') || document.createElement('form');
    form.appendChild(element);
    if (errorHtml && !errorInsideField) {
      const errorContainer = document.createElement('div');
      errorContainer.innerHTML = errorHtml;
      form.appendChild(errorContainer);
    }
    document.body.appendChild(form);

    return element;
  }

  it('does not have an error message by default', () => {
    const element = createAndConnectElement();

    expect(element.querySelector('.usa-error-message')).to.not.exist();
  });

  it('does not have an error message while the value is valid', async () => {
    const element = createAndConnectElement();

    const input = getByRole(element, 'textbox');
    await userEvent.type(input, '5');

    input.closest('form')!.checkValidity();

    expect(element.querySelector('.usa-error-message')).to.not.exist();
  });

  it('shows error state and focuses on form validation', () => {
    const element = createAndConnectElement();

    const input = getByRole(element, 'textbox') as HTMLInputElement;

    const form = element.parentNode as HTMLFormElement;
    form.checkValidity();

    expect(input.classList.contains('usa-input--error')).to.be.true();
    expect(input.getAttribute('aria-invalid')).to.equal('true');
    expect(document.activeElement).to.equal(input);
    expect(form.querySelector('.usa-error-message:not(.display-none)')).to.exist();
    expect(computeAccessibleDescription(document.activeElement!)).to.equal(
      'Required Field This field is required',
    );
  });

  it('shows custom validity as message content', () => {
    const element = createAndConnectElement();

    const input = getByRole(element, 'textbox') as HTMLInputElement;
    input.value = 'a';
    input.setCustomValidity('custom validity');

    const form = element.parentNode as HTMLFormElement;
    form.checkValidity();

    expect(getByText(element, 'custom validity')).to.be.ok();
  });

  it('clears existing validation state on input', async () => {
    const element = createAndConnectElement();

    const input = getByRole(element, 'textbox') as HTMLInputElement;

    const form = element.parentNode as HTMLFormElement;
    form.checkValidity();

    await userEvent.type(input, '5');

    expect(input.classList.contains('usa-input--error')).to.be.false();
    expect(input.getAttribute('aria-invalid')).to.equal('false');
    expect(form.querySelector('.usa-error-message:not(.display-none)')).not.to.exist();
    expect(computeAccessibleDescription(document.activeElement!)).to.equal('Required Field');
  });

  it('focuses the first element with an error', () => {
    const firstElement = createAndConnectElement();
    createAndConnectElement();

    const firstInput = getByRole(firstElement, 'textbox') as HTMLInputElement;

    const form = document.querySelector('form') as HTMLFormElement;

    form.checkValidity();

    expect(document.activeElement).to.equal(firstInput);
  });

  context('with initial error message', () => {
    it('clears existing validation state on input', async () => {
      const element = createAndConnectElement();

      const input = getByRole(element, 'textbox') as HTMLInputElement;

      const form = element.parentNode as HTMLFormElement;
      form.checkValidity();

      await userEvent.type(input, '5');

      expect(input.classList.contains('usa-input--error')).to.be.false();
      expect(input.getAttribute('aria-invalid')).to.equal('false');
      expect(() => getByText(element, 'Invalid value')).to.throw();
      expect(form.querySelector('.usa-error-message:not(.display-none)')).not.to.exist();
    });
  });

  context('with error message element pre-rendered in the DOM', () => {
    it('reuses the error message element from inside the tag', () => {
      const element = createAndConnectElement({ hasInitialError: true, errorInsideField: true });
      const input = getByRole(element, 'textbox');

      expect(computeAccessibleDescription(input)).to.equal('Required Field Invalid value');

      const form = element.parentNode as HTMLFormElement;
      form.checkValidity();

      expect(computeAccessibleDescription(input)).to.equal('Required Field This field is required');
      expect(() => getByText(element, 'Invalid value')).to.throw();
      expect(form.querySelector('.usa-error-message:not(.display-none)')).to.exist();
    });

    it('reuses the error message element from outside the tag', () => {
      const element = createAndConnectElement({ hasInitialError: true, errorInsideField: false });
      const input = getByRole(element, 'textbox');
      const form = element.parentNode as HTMLFormElement;

      expect(computeAccessibleDescription(input)).to.equal('Required Field Invalid value');

      form.checkValidity();

      expect(computeAccessibleDescription(input)).to.equal('Required Field This field is required');
      expect(() => getByText(form, 'Invalid value')).to.throw();
      expect(form.querySelector('.usa-error-message:not(.display-none)')).to.exist();
    });

    it('links input to external error message element when input is invalid', () => {
      const element = createAndConnectElement({ hasInitialError: false, errorInsideField: false });
      const form = element.parentNode as HTMLFormElement;

      form.checkValidity();

      const input = getByRole(element, 'textbox');
      expect(computeAccessibleDescription(input)).to.equal('Required Field This field is required');
      expect(form.querySelector('.usa-error-message:not(.display-none)')).to.exist();
    });

    it('clears error message when field becomes valid', async () => {
      const element = createAndConnectElement({ hasInitialError: true });
      const input = getByRole(element, 'textbox');
      await userEvent.type(input, '5');

      expect(computeAccessibleDescription(input)).to.equal('Required Field');
      expect(element.querySelector('.usa-error-message:not(.display-none)')).not.to.exist();
    });
  });

  context('text-like input', () => {
    it('sets max width on error message to match input', () => {
      const inputWidth = 280;
      const element = createAndConnectElement();

      const input = getByRole(element, 'textbox') as HTMLInputElement;
      sinon.stub(input, 'offsetWidth').value(inputWidth);

      const form = element.parentNode as HTMLFormElement;
      form.checkValidity();

      const message = getByText(element, 'This field is required');
      expect(message.style.maxWidth).to.equal(`${inputWidth}px`);
    });
  });

  context('non-text-like input', () => {
    it('does not set max width on error message', () => {
      const element = createAndConnectElement();

      const input = getByRole(element, 'textbox') as HTMLInputElement;
      input.type = 'checkbox';

      const form = element.parentNode as HTMLFormElement;
      form.checkValidity();

      const message = getByText(element, 'This field is required');
      expect(message.style.maxWidth).to.equal('');
    });
  });
});
