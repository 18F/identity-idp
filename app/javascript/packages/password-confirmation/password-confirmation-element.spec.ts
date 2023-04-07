import userEvent from '@testing-library/user-event';
import { getByLabelText } from '@testing-library/dom';
import { useSandbox } from '@18f/identity-test-helpers';
import * as analytics from '@18f/identity-analytics';
import './password-confirmation-element';
import type PasswordConfirmationElement from './password-confirmation-element';

describe('PasswordConfirmationElement', () => {
  let idCounter = 0;
  const sandbox = useSandbox();

  function createElement() {
    const element = document.createElement(
      'lg-password-confirmation',
    ) as PasswordConfirmationElement;
    const idSuffix = ++idCounter;
    element.innerHTML = `
      <label for="input-${idSuffix}">Password</label>
      <input id="input-${idSuffix}" class="password-confirmation__input1">
      <label for="input-${idSuffix}b">Confirm password</label>
      <input id="input-${idSuffix}b" class="password-confirmation__input2">
      <div class="password-toggle__toggle-wrapper">
        <input
          id="toggle-${idSuffix}"
          type="checkbox"
          class="password-toggle__toggle"
          aria-controls="input-${idSuffix}"
        >
        <label for="toggle-${idSuffix}" class="usa-checkbox__label password-toggle__toggle-label">
          Show password
        </label>
      </div>`;
    document.body.appendChild(element);
    return element;
  }

  it('initializes input type', () => {
    const element = createElement();

    const input = getByLabelText(element, 'Password') as HTMLInputElement;

    expect(input.type).to.equal('password');
  });

  it('changes input type on toggle', async () => {
    const element = createElement();

    const input = getByLabelText(element, 'Password') as HTMLInputElement;
    const toggle = getByLabelText(element, 'Show password') as HTMLInputElement;

    await userEvent.click(toggle);

    expect(input.type).to.equal('text');
  });

  it('logs an event when clicking the Show Password button', async () => {
    sandbox.stub(analytics, 'trackEvent');
    const element = createElement();
    const toggle = getByLabelText(element, 'Show password') as HTMLInputElement;

    await userEvent.click(toggle);

    expect(analytics.trackEvent).to.have.been.calledWith('Show Password button clicked', {
      path: window.location.pathname,
    });
  });

  it('should validate password confirmation', async () => {
    const element = createElement();
    const input1 = getByLabelText(element, 'Password') as HTMLInputElement;
    const input2 = getByLabelText(element, 'Confirm password') as HTMLInputElement;

    await userEvent.type(input1, 'different_password1');
    await userEvent.type(input2, 'different_password2');
    expect(input2.validity.customError).to.be.true;

    await userEvent.type(input1, 'matching_password!');
    await userEvent.type(input2, 'matching_password!');
    expect(input2.validity.customError).to.be.false;
  });
});
