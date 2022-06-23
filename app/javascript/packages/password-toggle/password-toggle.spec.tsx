import { createRef } from 'react';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import { render } from '@testing-library/react';
import PasswordToggle from './password-toggle';

describe('PasswordToggle', () => {
  it('renders with default labels', () => {
    const { getByLabelText } = render(<PasswordToggle />);

    expect(getByLabelText('components.password_toggle.label')).to.exist();
    expect(getByLabelText('components.password_toggle.toggle_label')).to.exist();
  });

  it('renders with custom input label', () => {
    const { getByLabelText } = render(<PasswordToggle label="Input" />);

    expect(getByLabelText('Input').classList.contains('password-toggle__input')).to.be.true();
  });

  it('renders with custom toggle label', () => {
    const { getByLabelText } = render(<PasswordToggle toggleLabel="Toggle" />);

    expect(getByLabelText('Toggle').classList.contains('password-toggle__toggle')).to.be.true();
  });

  it('renders default toggle position', () => {
    const { container } = render(<PasswordToggle />);

    expect(container.querySelector('.password-toggle--toggle-top')).to.exist();
  });

  it('renders explicit toggle position', () => {
    const { container } = render(<PasswordToggle togglePosition="bottom" />);

    expect(container.querySelector('.password-toggle--toggle-bottom')).to.exist();
  });

  it('applies custom class to wrapper element', () => {
    const { container } = render(<PasswordToggle label="Input" className="my-custom-class" />);

    expect(container.querySelector('lg-password-toggle.my-custom-class')).to.exist();
  });

  it('passes additional props to underlying text input', () => {
    const type = 'password';
    const { getByLabelText } = render(<PasswordToggle label="Input" type={type} />);

    const input = getByLabelText('Input') as HTMLInputElement;

    expect(input.type).to.equal(type);
  });

  it('forwards ref to the underlying text input', () => {
    const ref = createRef<HTMLInputElement>();
    render(<PasswordToggle ref={ref} />);

    expect(ref.current).to.be.an.instanceOf(HTMLInputElement);
  });

  it('validates input as a ValidatedField', () => {
    const { getByLabelText } = render(<PasswordToggle label="Input" required />);

    const input = getByLabelText('Input') as HTMLInputElement;

    input.reportValidity();
    const description = computeAccessibleDescription(input);
    expect(description).to.equal('simple_form.required.text');
  });
});
