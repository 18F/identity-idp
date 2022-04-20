import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import FormStepsContext, { DEFAULT_CONTEXT } from './form-steps-context';
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

  it('submits using FormStepsContext', () => {
    const toNextStep = sinon.spy();

    const { getByRole } = render(
      <FormStepsContext.Provider value={{ ...DEFAULT_CONTEXT, toNextStep }}>
        <FormStepsContinueButton />
      </FormStepsContext.Provider>,
    );

    const button = getByRole('button');
    userEvent.click(button);

    expect(toNextStep).to.have.been.called();
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
