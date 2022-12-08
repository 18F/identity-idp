import { createRef } from 'react';
import { render } from '@testing-library/react';
import TextInput from './text-input';

describe('TextInput', () => {
  it('renders with an associated label', () => {
    const { getByLabelText } = render(<TextInput label="Input" />);

    const input = getByLabelText('Input');

    expect(input).to.be.an.instanceOf(HTMLInputElement);
    expect(input.classList.contains('usa-input')).to.be.true();
  });

  it('uses an explicitly-provided ID', () => {
    const customId = 'custom-id';
    const { getByLabelText } = render(<TextInput label="Input" id={customId} />);

    const input = getByLabelText('Input');

    expect(input.id).to.equal(customId);
  });

  it('applies additional given classes', () => {
    const customClass = 'custom-class';
    const { getByLabelText } = render(<TextInput label="Input" className={customClass} />);

    const input = getByLabelText('Input');

    expect([...input.classList.values()]).to.have.all.members(['usa-input', customClass]);
  });

  it('applies additional input attributes', () => {
    const type = 'password';
    const { getByLabelText } = render(<TextInput label="Input" type={type} />);

    const input = getByLabelText('Input') as HTMLInputElement;

    expect(input.type).to.equal(type);
  });

  it('forwards ref', () => {
    const ref = createRef<HTMLInputElement>();
    render(<TextInput label="Input" ref={ref} />);

    expect(ref.current).to.be.an.instanceOf(HTMLInputElement);
  });

  it('renders with a hint', () => {
    const { getByText } = render(<TextInput label="Input" hint="Something special" />);

    const input = getByText('Something special');

    expect(input).to.be.an.instanceOf(HTMLDivElement);
    expect(input.classList.contains('usa-hint')).to.be.true();
  });
});
