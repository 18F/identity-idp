import { render } from '@testing-library/react';
import FormStepsButton from './form-steps-button';

describe('FormStepsButton', () => {
  it('renders wrapper with class names', () => {
    const { container } = render(<FormStepsButton.Continue />);

    const wrapper = container.firstElementChild!;

    expect(Array.from(wrapper.classList.values())).to.include.members(['margin-y-5']);
  });

  context('with className prop', () => {
    it('applies additional class names', () => {
      const { container } = render(<FormStepsButton.Continue className="my-custom-class" />);

      const wrapper = container.firstElementChild!;

      expect(Array.from(wrapper.classList.values())).to.include.members(['margin-y-5', 'my-custom-class']);
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
