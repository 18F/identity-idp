import { render } from '@testing-library/react';
import FormStepsButton from './form-steps-button';

describe('FormStepsButton', () => {
  it('renders button with class names', () => {
    const { getByRole } = render(<FormStepsButton.Continue />);

    const button = getByRole('button');

    expect(Array.from(button.classList.values())).to.include.members([
      'display-block',
      'margin-y-5',
    ]);
  });

  context('with className prop', () => {
    it('applies additional class names', () => {
      const { getByRole } = render(<FormStepsButton.Continue className="my-custom-class" />);

      const button = getByRole('button');

      expect(Array.from(button.classList.values())).to.include.members([
        'display-block',
        'margin-y-5',
        'my-custom-class',
      ]);
    });
  });

  describe('.Continue', () => {
    it('renders with continue label', () => {
      const { getByRole } = render(<FormStepsButton.Continue />);

      expect(getByRole('button', { name: 'forms.buttons.continue' })).to.be.ok();
    });
  });

  describe('.Submit', () => {
    it('renders with submit label', () => {
      const { getByRole } = render(<FormStepsButton.Submit />);

      expect(getByRole('button', { name: 'forms.buttons.submit.default' })).to.be.ok();
    });
  });
});
