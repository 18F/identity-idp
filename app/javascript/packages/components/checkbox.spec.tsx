import { render } from '@testing-library/react';
import Checkbox from './checkbox';

describe('Checkbox', () => {
  it('renders given checkbox', () => {
    const { getByRole, getByText } = render(
      <Checkbox id="checkbox1" label="A checkbox" labelDescription="A checkbox for testing" />,
    );

    const checkbox = getByRole('checkbox');
    expect(checkbox.classList.contains('usa-checkbox__input')).to.be.true();
    expect(checkbox.classList.contains('usa-button__input-title')).to.be.false();
    expect(checkbox.id).to.eq('checkbox1');

    const label = getByText('A checkbox');
    expect(label).to.be.ok();
    expect(label.classList.contains('usa-checkbox__label')).to.be.true();
    expect(label.getAttribute('for')).eq('checkbox1');

    const labelDescription = getByText('A checkbox for testing');
    expect(labelDescription).to.be.ok();
    expect(labelDescription.classList.contains('usa-checkbox__label-description')).to.be.true();
  });

  context('with isTitle', () => {
    it('renders with correct style', () => {
      const { getByRole } = render(
        <Checkbox isTitle label="A checkbox" labelDescription="A checkbox for testing" />,
      );
      const checkbox = getByRole('checkbox');
      expect(checkbox.classList.contains('usa-button__input-title')).to.be.true();
    });
  });

  context('with hint', () => {
    it('renders hint', () => {
      const { getByText } = render(
        <Checkbox
          isTitle
          label="A checkbox"
          labelDescription="A checkbox for testing"
          hint="Please check this box"
        />,
      );
      const hint = getByText('Please check this box');
      expect(hint).to.be.ok();
    });
  });
});
