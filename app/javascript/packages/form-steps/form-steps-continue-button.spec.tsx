import { render } from '@testing-library/react';
import FormStepsContinueButton from './form-steps-continue-button';

describe('FormStepsContinueButton', () => {
  it('renders button with class names', () => {
    const { getByRole } = render(<FormStepsContinueButton />);

    const button = getByRole('button');

    expect(Array.from(button.classList.values())).to.include.members([
      'display-block',
      'margin-y-5',
    ]);
  });

  context('with className prop', () => {
    it('applies additional class names', () => {
      const { getByRole } = render(<FormStepsContinueButton className="my-custom-class" />);

      const button = getByRole('button');

      expect(Array.from(button.classList.values())).to.include.members([
        'display-block',
        'margin-y-5',
        'my-custom-class',
      ]);
    });
  });
});
