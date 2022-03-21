import userEvent from '@testing-library/user-event';
import { PasswordToggleElement } from './index';

describe('PasswordToggleElement', () => {
  let idCounter = 0;

  before(() => {
    if (!customElements.get('lg-password-toggle')) {
      customElements.define('lg-password-toggle', PasswordToggleElement);
    }
  });

  function createElement() {
    const element = document.createElement('lg-password-toggle') as PasswordToggleElement;
    const idSuffix = ++idCounter;
    element.innerHTML = `
      <input id="input-${idSuffix}" class="password-toggle__input">
      <div class="password-toggle__toggle-wrapper">
        <input
          id="toggle-${idSuffix}"
          type="checkbox"
          class="password-toggle__toggle"
          aria-controls="input-${idSuffix}"
        >
        <label
          for="toggle-${idSuffix}"
          class="usa-checkbox__label password-toggle__toggle-label"
        >
          <%= toggle_label %>
        </label>
      </div>
      <script type="application/json" class="password-toggle__strings">
        {
          "visible": "Password is visible",
          "hidden": "Password is hidden"
        }
      </script>
      <div class="password-toggle__visible-state usa-sr-only" role="status"></div>`;
    document.body.appendChild(element);
    return element;
  }

  it('initializes input type', () => {
    const { input } = createElement().elements;

    expect(input.type).to.equal('password');
  });

  it('changes input type on toggle', () => {
    const { input, toggle } = createElement().elements;

    userEvent.click(toggle);

    expect(input.type).to.equal('text');
  });

  it('announces visible state on toggle', () => {
    const { toggle, visibleState } = createElement().elements;

    expect(visibleState.textContent).to.be.empty();

    userEvent.click(toggle);

    expect(visibleState.textContent).to.equal('Password is visible');

    userEvent.click(toggle);

    expect(visibleState.textContent).to.equal('Password is hidden');
  });
});
