import { createRef } from 'react';
import { render } from '@testing-library/react';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import SelectInput from './select-input';

describe('SelectInput', () => {
  it('renders with an associated label', () => {
    const { getByLabelText } = render(<SelectInput label="Input">test</SelectInput>);

    const input = getByLabelText('Input');

    expect(input).to.be.an.instanceOf(HTMLInputElement);
    expect(input.classList.contains('usa-input')).to.be.true();
  });

  it('uses an explicitly-provided ID', () => {
    const customId = 'custom-id';
    const { getByLabelText } = render(
      <SelectInput label="Input" id={customId}>
        test
      </SelectInput>,
    );

    const input = getByLabelText('Input');

    expect(input.id).to.equal(customId);
  });

  it('applies additional given classes', () => {
    const customClass = 'custom-class';
    const { getByLabelText } = render(
      <SelectInput label="Input" className={customClass}>
        test
      </SelectInput>,
    );

    const input = getByLabelText('Input');

    expect([...input.classList.values()]).to.have.all.members(['usa-input', customClass]);
  });

  it('applies additional input attributes', () => {
    const type = 'password';
    const { getByLabelText } = render(
      <SelectInput label="Input" type={type}>
        test
      </SelectInput>,
    );

    const input = getByLabelText('Input') as HTMLInputElement;

    expect(input.type).to.equal(type);
  });

  it('forwards ref', () => {
    const ref = createRef<HTMLSelectElement>();
    render(
      <SelectInput label="Input" ref={ref}>
        test
      </SelectInput>,
    );

    expect(ref.current).to.be.an.instanceOf(HTMLInputElement);
  });

  it('renders with a hint', () => {
    const { getByLabelText, getByText } = render(
      <SelectInput label="Input" hint="Something special">
        test
      </SelectInput>,
    );

    const input = getByLabelText('Input');
    const description = computeAccessibleDescription(input);
    const hint = getByText('Something special');

    expect(description).to.equal('Something special');
    expect(hint.classList.contains('usa-hint')).to.be.true();
  });
});
