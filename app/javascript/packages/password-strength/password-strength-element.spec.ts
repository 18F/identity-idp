import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import './password-strength-element';

describe('PasswordStrengthElement', () => {
  function createElement() {
    document.body.innerHTML = `
      <input id="password-input">
      <lg-password-strength
        input-id="password-input"
        minimum-length="12"
        forbidden-passwords="[&quot;password&quot;]"
        class="ads-password-strength"
        data-open="false"
        hidden
      >
        <div class="ads-password-strength__inner">
          <div class="ads-password-strength__row">
            <div class="ads-password-strength__track" aria-hidden="true">
              <span class="ads-password-strength__bar"></span>
            </div>
            <p class="ads-password-strength__feedback" id="password-input-password-strength" aria-live="polite"></p>
          </div>
        </div>
      </lg-password-strength>
    `;

    return document.querySelector('lg-password-strength')!;
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
});
