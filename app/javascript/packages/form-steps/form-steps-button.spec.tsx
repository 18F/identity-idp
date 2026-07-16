import { render } from '@testing-library/react';
import FormStepsButton from './form-steps-button';

describe('FormStepsButton', () => {
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
