import userEvent from '@testing-library/user-event';
import { getByLabelText, waitFor } from '@testing-library/dom';
import './password-confirmation-element';
import type PasswordConfirmationElement from './password-confirmation-element';

describe('PasswordConfirmationElement', () => {
  let element: PasswordConfirmationElement;
  let input1: HTMLInputElement;
  let input2: HTMLInputElement;
  let idCounter = 0;

  function createElement() {
    element = document.createElement('lg-password-confirmation') as PasswordConfirmationElement;
    const idSuffix = ++idCounter;
    element.innerHTML = `
      <label for="input-${idSuffix}">Password</label>
      <input id="input-${idSuffix}" class="password-confirmation__input">
      <label for="input-${idSuffix}b">Confirm password</label>
      <input id="input-${idSuffix}b" class="password-confirmation__input-confirmation">
      <div class="password-confirmation__toggle-wrapper">
        <input
          id="toggle-${idSuffix}"
          type="checkbox"
          class="password-confirmation__toggle"
          aria-controls="input-${idSuffix}"
        >
        <label for="toggle-${idSuffix}" class="usa-checkbox__label password-confirmation__toggle-label">
          Show password
        </label>
      </div>`;
    document.body.appendChild(element);
    return element;
  }

  beforeEach(() => {
    element = createElement();
    input1 = getByLabelText(element, 'Password') as HTMLInputElement;
    input2 = getByLabelText(element, 'Confirm password') as HTMLInputElement;
  });

  it('initializes input type', () => {
    expect(input1.type).to.equal('password');
  });

  it('changes input type on toggle', async () => {
    const toggle = getByLabelText(element, 'Show password') as HTMLInputElement;

    await userEvent.click(toggle);

    expect(input1.type).to.equal('text');
  });

  describe('Password validation', () => {
    it('validates passwords in both directions', async () => {
      await userEvent.type(input1, 'salty pickles');
      await userEvent.type(input2, 'salty pickles2');
      await waitFor(() => {
        expect(input2.checkValidity()).to.be.false();
      });

      await userEvent.clear(input1);
      await userEvent.type(input1, 'salty pickles2');
      await waitFor(() => {
        expect(input2.checkValidity()).to.be.true();
      });

      await userEvent.clear(input1);
      await userEvent.type(input1, 'salty pickles3');
      await waitFor(() => {
        expect(input2.checkValidity()).to.be.false();
      });

      await userEvent.clear(input2);
      await userEvent.type(input2, 'salty pickles3');
      await waitFor(() => {
        expect(input2.checkValidity()).to.be.true();
      });
    });
  });
});
