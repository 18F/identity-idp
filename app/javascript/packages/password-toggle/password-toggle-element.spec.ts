import userEvent from '@testing-library/user-event';
import { getByLabelText } from '@testing-library/dom';
import './password-toggle-element';
import type PasswordToggleElement from './password-toggle-element';

describe('PasswordToggleElement', () => {
  let idCounter = 0;

  function createElement() {
    const element = document.createElement('lg-password-toggle') as PasswordToggleElement;
    const idSuffix = ++idCounter;
    element.innerHTML = `
      <label for="input-${idSuffix}">Password</label>
      <input id="input-${idSuffix}" class="password-toggle__input">
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
});
