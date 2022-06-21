import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import PersonalKeyInput from './personal-key-input';

describe('PersonalKeyInput', () => {
  it('accepts a value with dashes', async () => {
    const value = '0000-0000-0000-0000';
    const { getByRole } = render(<PersonalKeyInput />);

    const input = getByRole('textbox') as HTMLInputElement;
    await userEvent.type(input, value);

    expect(input.value).to.equal(value);
  });

  it('accepts a value without dashes', async () => {
    const { getByRole } = render(<PersonalKeyInput />);

    const input = getByRole('textbox') as HTMLInputElement;
    await userEvent.type(input, '0000000000000000');

    expect(input.value).to.equal('0000-0000-0000-0000');
  });

  it('does not accept a code longer than one with dashes', async () => {
    const { getByRole } = render(<PersonalKeyInput />);

    const input = getByRole('textbox') as HTMLInputElement;
    await userEvent.type(input, '0000-0000-0000-00000');

    expect(input.value).to.equal('0000-0000-0000-0000');
  });

  it('formats value as the user types', async () => {
    const { getByRole } = render(<PersonalKeyInput />);

    const input = getByRole('textbox') as HTMLInputElement;

    await userEvent.type(input, '1234');
    expect(input.value).to.equal('1234-');

    await userEvent.type(input, '-');
    expect(input.value).to.equal('1234-');

    await userEvent.paste('12341234');
    expect(input.value).to.equal('1234-1234-1234-');

    await userEvent.type(input, '12345');
    expect(input.value).to.equal('1234-1234-1234-1234');
  });

  it('allows the user to paste the personal key from their clipboard', async () => {
    const { getByRole } = render(<PersonalKeyInput />);

    const input = getByRole('textbox') as HTMLInputElement;

    input.focus();
    await userEvent.paste('1234-1234-1234-1234');

    expect(input.value).to.equal('1234-1234-1234-1234');
  });

  it('validates the input value against the expected value (case-insensitive, crockford)', async () => {
    const { getByRole } = render(<PersonalKeyInput expectedValue="abcd-0011-DEFG-1111" />);

    const input = getByRole('textbox') as HTMLInputElement;

    await userEvent.type(input, 'ABCDoOlL-defg-iI1');
    input.checkValidity();
    expect(input.validationMessage).to.equal('users.personal_key.confirmation_error');

    await userEvent.type(input, '1');
    input.checkValidity();
    expect(input.validity.valid).to.be.true();
  });
});
