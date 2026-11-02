import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import './password-strength-element';

describe('NDS PasswordStrengthElement', () => {
  function createElement() {
    document.body.innerHTML = `
      <input id="password-input">
      <lg-nds-password-strength
        input-id="password-input"
        minimum-length="12"
        forbidden-passwords="[&quot;password&quot;]"
        class="password-strength"
        data-open="false"
        hidden
      >
        <div class="password-strength__inner">
          <div class="password-strength__row">
            <div class="password-strength__track" aria-hidden="true">
              <span class="password-strength__bar"></span>
            </div>
            <p class="password-strength__feedback" id="password-input-password-strength" aria-live="polite"></p>
          </div>
        </div>
      </lg-nds-password-strength>
    `;

    return document.querySelector('lg-nds-password-strength')!;
  }

  it('is shown when a value is entered', async () => {
    const element = createElement();

    await userEvent.type(screen.getByRole('textbox'), 'p');

    expect(element.hidden).to.be.false();
  });

  it('is hidden when a value is removed', async () => {
    const element = createElement();
    const input = screen.getByRole('textbox');

    await userEvent.type(input, 'p');
    await userEvent.clear(input);

    expect(element.hidden).to.be.true();
  });

  it('maps weak passwords to score 1', async () => {
    const element = createElement();

    await userEvent.type(screen.getByRole('textbox'), 'p');

    expect(element.getAttribute('data-score')).to.equal('1');
    expect(screen.getByText('instructions.password.strength.1')).to.exist();
  });

  it('invalidates input when value is not strong enough', async () => {
    createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');
    await userEvent.type(input, 'p');

    expect(input.validity.valid).to.be.false();
  });

  it('shows too-common feedback for forbidden passwords', async () => {
    const element = createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');
    await userEvent.type(input, 'password');

    expect(element.getAttribute('data-score')).to.equal('1');
    expect(screen.getByText('instructions.password.strength.too_common')).to.exist();
    expect(input.validity.valid).to.be.false();
  });

  it('updates the password aria-describedby attribute', async () => {
    createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');

    await userEvent.type(input, 'password');
    expect(input.getAttribute('aria-describedby')).to.equal('password-input-password-strength');

    await userEvent.clear(input);
    expect(input.hasAttribute('aria-describedby')).to.be.false();
  });

  it('caps score when zxcvbn is strong but password is too short', async () => {
    const element = createElement();

    await userEvent.type(screen.getByRole('textbox'), 'mRd@fX!f&G');

    expect(element.getAttribute('data-score')).to.equal('2');
    expect(screen.getByText('instructions.password.strength.3')).to.exist();
  });

  it('marks a strong long password valid', async () => {
    const element = createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');
    await userEvent.type(input, 'mRd@fX!f&G?_*');

    expect(element.getAttribute('data-score')).to.equal('3');
    expect(screen.getByText('instructions.password.strength.strong')).to.exist();
    expect(input.validity.valid).to.be.true();
  });

  it('does not restore stale strength after the value is cleared', async () => {
    const element = createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');

    // Dispatch synchronously so the clear is handled while scoring of the previous value is
    // still in flight, which is what the deferred zxcvbn load makes possible.
    input.value = 'p';
    input.dispatchEvent(new Event('input'));
    input.value = '';
    input.dispatchEvent(new Event('input'));

    await new Promise((resolve) => {
      setTimeout(resolve, 0);
    });

    expect(element.hidden).to.be.true();
    expect(input.hasAttribute('aria-describedby')).to.be.false();
  });
});
