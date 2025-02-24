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
        class="display-none"
      >
        <div class="password-strength__meter">
          <div class="password-strength__meter-bar"></div>
          <div class="password-strength__meter-bar"></div>
          <div class="password-strength__meter-bar"></div>
          <div class="password-strength__meter-bar"></div>
        </div>
        Password strength:
        <span class="password-strength__strength"></span>
        <div class="password-strength__feedback"></div>
      </lg-password-strength>
    `;

    return document.querySelector('lg-password-strength')!;
  }

  it('is shown when a value is entered', async () => {
    const element = createElement();

    const input = screen.getByRole('textbox');
    await userEvent.type(input, 'p');

    expect(element.classList.contains('display-none')).to.be.false();
  });

  it('is hidden when a value is removed', async () => {
    const element = createElement();

    const input = screen.getByRole('textbox');
    await userEvent.type(input, 'p');
    await userEvent.clear(input);

    expect(element.classList.contains('display-none')).to.be.true();
  });

  it('displays strength and feedback for a given password', async () => {
    const element = createElement();

    const input = screen.getByRole('textbox');
    await userEvent.type(input, 'p');

    expect(element.getAttribute('score')).to.equal('0');
    expect(screen.getByText('instructions.password.strength.0')).to.exist();
    expect(
      screen.getByText('zxcvbn.feedback.add_another_word_or_two_uncommon_words_are_better'),
    ).to.exist();
  });

  it('invalidates input when value is not strong enough', async () => {
    createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');
    await userEvent.type(input, 'p');

    expect(input.validity.valid).to.be.false();
  });

  it('shows custom feedback for forbidden password', async () => {
    const element = createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');
    await userEvent.type(input, 'password');

    expect(element.getAttribute('score')).to.equal('0');
    expect(screen.getByText('instructions.password.strength.0')).to.exist();
    expect(
      screen.getByText('errors.attributes.password.avoid_using_phrases_that_are_easily_guessed'),
    ).to.exist();
    expect(input.validity.valid).to.be.false();
  });

  it('updates the password aria-describedby attribute', async () => {
    createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');

    await userEvent.type(input, 'password');

    expect(input.getAttribute('aria-describedby')).to.equal('password-strength ');
  });

  it('shows concatenated suggestions from zxcvbn if there is no specific warning', async () => {
    createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');
    await userEvent.type(input, 'PASSWORD');

    expect(
      screen.getByText(
        'zxcvbn.feedback.add_another_word_or_two_uncommon_words_are_better. ' +
          'zxcvbn.feedback.all_uppercase_is_almost_as_easy_to_guess_as_all_lowercase',
      ),
    ).to.exist();
    expect(input.validity.valid).to.be.false();
  });

  it('shows feedback for a password that satisfies zxcvbn but is too short', async () => {
    const element = createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');
    await userEvent.type(input, 'mRd@fX!f&G');

    expect(element.getAttribute('score')).to.equal('2');
    expect(screen.getByText('instructions.password.strength.2')).to.exist();
    expect(screen.getByText('errors.attributes.password.too_short.other')).to.exist();
    expect(input.validity.valid).to.be.false();
  });

  it('shows feedback for a password that is valid', async () => {
    const element = createElement();

    const input: HTMLInputElement = screen.getByRole('textbox');
    await userEvent.type(input, 'mRd@fX!f&G?_*');

    expect(element.getAttribute('score')).to.equal('4');
    expect(screen.getByText('instructions.password.strength.4')).to.exist();
    expect(
      element.querySelector('.password-strength__feedback')!.textContent!.trim(),
    ).to.be.empty();
    expect(input.validity.valid).to.be.true();
  });
});
