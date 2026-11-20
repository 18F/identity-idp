import { createRef } from 'react';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import NDSTextInput from './nds-text-input';

describe('NDSTextInput', () => {
  it('renders the NDS::InputComponent floating-label markup', () => {
    const { container, getByLabelText } = render(<NDSTextInput label="City" />);

    const input = getByLabelText('City') as HTMLInputElement;
    expect(container.firstElementChild!.classList.contains('usa-input')).to.be.true();
    expect(input.classList.contains('usa-input__control')).to.be.true();
    expect(input.classList.contains('usa-input__control--floating')).to.be.true();
    expect(input.placeholder).to.equal(' ');
    expect(input.closest('.usa-input__shell')).to.exist();

    const floatingLabel = input.nextElementSibling!;
    expect(floatingLabel.classList.contains('usa-input__floating-label')).to.be.true();
    expect(floatingLabel.getAttribute('aria-hidden')).to.equal('true');
    expect(floatingLabel.textContent).to.equal('City');

    const error = container.querySelector('.usa-input__error')!;
    expect(error.classList.contains('usa-input__error--visible')).to.be.false();
    expect(input.getAttribute('aria-invalid')).to.equal('false');
  });

  it('assigns both the forwarded ref and the field ref', () => {
    const ref = createRef<HTMLInputElement>();
    const fieldRef = createRef<HTMLInputElement>();
    const { getByLabelText } = render(<NDSTextInput label="City" ref={ref} fieldRef={fieldRef} />);

    expect(ref.current).to.equal(getByLabelText('City'));
    expect(fieldRef.current).to.equal(getByLabelText('City'));
  });

  it('shows the validity message inline instead of the browser bubble', () => {
    const { container, getByLabelText } = render(<NDSTextInput label="City" required />);
    const input = getByLabelText('City') as HTMLInputElement;

    input.reportValidity();

    const error = container.querySelector('.usa-input__error')!;
    expect(error.classList.contains('usa-input__error--visible')).to.be.true();
    expect(error.textContent).to.equal('simple_form.required.text');
    expect(input.getAttribute('aria-invalid')).to.equal('true');
    expect(input.getAttribute('aria-describedby')).to.equal(error.id);
  });

  it('uses the given message for a validity state', async () => {
    const { container, getByLabelText } = render(
      <NDSTextInput label="Zip" pattern="\d{5}" messages={{ patternMismatch: 'Enter 5 digits' }} />,
    );
    const input = getByLabelText('Zip');

    await userEvent.type(input, '12');
    await userEvent.tab();

    expect(container.querySelector('.usa-input__error')!.textContent).to.equal('Enter 5 digits');
  });

  it('does not validate an empty field on blur', async () => {
    const { container, getByLabelText } = render(<NDSTextInput label="City" required />);

    await userEvent.click(getByLabelText('City'));
    await userEvent.tab();

    expect(container.querySelector('.usa-input__error--visible')).not.to.exist();
  });

  it('clears the error when the user types', async () => {
    const { container, getByLabelText } = render(<NDSTextInput label="City" required />);
    const input = getByLabelText('City') as HTMLInputElement;

    input.reportValidity();
    await userEvent.type(input, 'P');

    expect(container.querySelector('.usa-input__error--visible')).not.to.exist();
    expect(input.getAttribute('aria-invalid')).to.equal('false');
    expect(input.hasAttribute('aria-describedby')).to.be.false();
  });
});
