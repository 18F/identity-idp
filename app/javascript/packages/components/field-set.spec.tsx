import { render } from '@testing-library/react';
import FieldSet from './field-set';

describe('FieldSet', () => {
  it('renders given fieldset', () => {
    const { getByRole, getByText } = render(
      <FieldSet>
        <p>Inner text</p>
      </FieldSet>,
    );
    const fieldSet = getByRole('group');
    expect(fieldSet).to.be.ok();
    expect(fieldSet.classList.contains('usa-fieldset')).to.be.true();

    const child = getByText('Inner text');
    expect(child).to.be.ok();
  });
  context('with legend', () => {
    it('renders legend', () => {
      const { getByText } = render(
        <FieldSet legend="Legend text">
          <p>Inner text</p>
        </FieldSet>,
      );
      const legend = getByText('Legend text');
      expect(legend).to.be.ok();
      expect(legend.classList.contains('usa-legend')).to.be.true();
    });
  });
});
