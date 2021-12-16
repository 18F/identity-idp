import sinon from 'sinon';
import { getByRole, getByText } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { ValidatedField } from '.';

describe('ValidatedField', () => {
  before(() => {
    customElements.define('lg-validated-field', ValidatedField);
  });

  let idCounter = 0;

  function createAndConnectElement({ hasInitialError = false } = {}) {
    const element = document.createElement('lg-validated-field');
    const errorMessageId = ++idCounter;
    element.innerHTML = `
      <script type="application/json" class="validated-field__error-strings">
        {
          "valueMissing": "This field is required"
        }
      </script>
      <div class="validated-field__input-wrapper">
        <input
          aria-invalid="false"
          aria-describedby="validated-field-error-${errorMessageId}"
          required="required"
          aria-required="true"
          class="validated-field__input${hasInitialError ? ' usa-input--error' : ''}"
        />
        ${
          hasInitialError
            ? `<div class="usa-error-message" id="validated-field-error-${errorMessageId}">Invalid value</div>`
            : ''
        }
      </div>
    `;

    const form = document.createElement('form');
    form.appendChild(element);
    document.body.appendChild(form);

    return element;
  }

  it('shows error state and focuses on form validation', () => {
    const element = createAndConnectElement();

    /** @type {HTMLInputElement} */
    const input = getByRole(element, 'textbox');

    /** @type {HTMLFormElement} */
    const form = element.parentNode;
    form.checkValidity();

    expect(input.classList.contains('usa-input--error')).to.be.true();
    expect(input.getAttribute('aria-invalid')).to.equal('true');
    expect(document.activeElement).to.equal(input);
    const message = getByText(element, 'This field is required');
    expect(message).to.be.ok();
    expect(message.id).to.equal(input.getAttribute('aria-describedby'));
  });

  it('shows custom validity as message content', () => {
    const element = createAndConnectElement();

    /** @type {HTMLInputElement} */
    const input = getByRole(element, 'textbox');
    input.value = 'a';
    input.setCustomValidity('custom validity');

    /** @type {HTMLFormElement} */
    const form = element.parentNode;
    form.checkValidity();

    expect(getByText(element, 'custom validity')).to.be.ok();
  });

  it('clears existing validation state on input', () => {
    const element = createAndConnectElement();

    /** @type {HTMLInputElement} */
    const input = getByRole(element, 'textbox');

    /** @type {HTMLFormElement} */
    const form = element.parentNode;
    form.checkValidity();

    userEvent.type(input, '5');

    expect(input.classList.contains('usa-input--error')).to.be.false();
    expect(input.getAttribute('aria-invalid')).to.equal('false');
    expect(() => getByText(element, 'This field is required')).to.throw();
  });

  it('focuses the first element with an error', () => {
    const firstElement = createAndConnectElement();
    createAndConnectElement();

    /** @type {HTMLInputElement} */
    const firstInput = getByRole(firstElement, 'textbox');

    /** @type {HTMLFormElement} */
    const form = document.querySelector('form');

    form.checkValidity();

    expect(document.activeElement).to.equal(firstInput);
  });

  context('with initial error message', () => {
    it('clears existing validation state on input', () => {
      const element = createAndConnectElement();

      /** @type {HTMLInputElement} */
      const input = getByRole(element, 'textbox');

      /** @type {HTMLFormElement} */
      const form = element.parentNode;
      form.checkValidity();

      userEvent.type(input, '5');

      expect(input.classList.contains('usa-input--error')).to.be.false();
      expect(input.getAttribute('aria-invalid')).to.equal('false');
      expect(() => getByText(element, 'Invalid value')).to.throw();
    });
  });

  context('text-like input', () => {
    it('sets max width on error message to match input', () => {
      const inputWidth = 280;
      const element = createAndConnectElement();

      /** @type {HTMLInputElement} */
      const input = getByRole(element, 'textbox');
      sinon.stub(input, 'offsetWidth').value(inputWidth);

      /** @type {HTMLFormElement} */
      const form = element.parentNode;
      form.checkValidity();

      const message = getByText(element, 'This field is required');
      expect(message.style.maxWidth).to.equal(`${inputWidth}px`);
    });
  });

  context('non-text-like input', () => {
    it('does not set max width on error message', () => {
      const element = createAndConnectElement();

      /** @type {HTMLInputElement} */
      const input = getByRole(element, 'textbox');
      input.type = 'checkbox';

      /** @type {HTMLFormElement} */
      const form = element.parentNode;
      form.checkValidity();

      const message = getByText(element, 'This field is required');
      expect(message.style.maxWidth).to.equal('');
    });
  });
});
