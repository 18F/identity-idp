import { createRef } from 'react';
import { render } from '@testing-library/react';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import SelectInput from './select-input';

describe('SelectInput', () => {
  it('renders with an associated label', () => {
    const { getByLabelText } = render(<SelectInput label="Input">test</SelectInput>);

    const input = getByLabelText('Input');

    expect(input).to.be.an.instanceOf(HTMLSelectElement);
    expect(input.classList.contains('usa-select')).to.be.true();
  });

  it('renders with child elements', () => {
    const childElement = <option value="abc">def</option>;
    const { getByText, getByLabelText } = render(
      <SelectInput label="Input">{childElement}</SelectInput>,
    );

    const input = getByLabelText('Input');

    expect(input).to.be.an.instanceOf(HTMLSelectElement);
    const optionElement = getByText('def');
    expect(optionElement).to.be.an.instanceOf(HTMLOptionElement);
    expect((optionElement as HTMLOptionElement).selected).to.be.true();
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

    expect([...input.classList.values()]).to.have.all.members(['usa-select', customClass]);
  });

  it('applies additional input attributes', () => {
    const value = 'password';
    const { getByLabelText } = render(
      <SelectInput label="Input" title={value}>
        test
      </SelectInput>,
    );

    const input = getByLabelText('Input');

    expect(input.title).to.equal(value);
  });

  it('forwards ref', () => {
    const ref = createRef<HTMLSelectElement>();
    render(
      <SelectInput label="Input" ref={ref}>
        test
      </SelectInput>,
    );

    expect(ref.current).to.be.an.instanceOf(HTMLSelectElement);
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
