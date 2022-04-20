import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { FormSteps } from '@18f/identity-form-steps';
import PersonalKeyConfirmStep from './personal-key-confirm-step';

describe('PersonalKeyConfirmStep', () => {
  const DEFAULT_PROPS = {
    onChange() {},
    value: { personalKey: '' },
    errors: [],
    unknownFieldErrors: [],
    onError() {},
    registerField: () => () => {},
  };

  it('allows the user to return to the previous step by clicking "Back" button', async () => {
    const toPreviousStep = sinon.spy();
    const { getByText } = render(
      <PersonalKeyConfirmStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
    );

    await userEvent.click(getByText('forms.buttons.back'));

    expect(toPreviousStep).to.have.been.called();
  });

  it('allows the user to return to the previous step by pressing Escape', async () => {
    const toPreviousStep = sinon.spy();
    const { getByRole } = render(
      <PersonalKeyConfirmStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
    );

    await userEvent.type(getByRole('textbox'), '{Escape}');

    expect(toPreviousStep).to.have.been.called();
  });

  it('allows the user to continue only with a correct value', () => {
    const personalKey = '0000-0000-0000-0000';
    const onComplete = sinon.spy();
    const { getByLabelText, getAllByText, container } = render(
      <FormSteps
        steps={[{ name: 'personal_key_confirm', form: PersonalKeyConfirmStep }]}
        initialValues={{ personalKey }}
        onComplete={onComplete}
      />,
    );

    const input = getByLabelText('forms.personal_key.confirmation_label');
    const submitButton = getAllByText('forms.buttons.submit.default')[1];
    userEvent.click(submitButton);

    expect(onComplete).not.to.have.been.called();
    expect(container.ownerDocument.activeElement).to.equal(input);
    const errorMessage = document.getElementById(input.getAttribute('aria-describedby')!)!;
    expect(errorMessage.textContent).to.equal('users.personal_key.confirmation_error');

    userEvent.type(input, personalKey);
    userEvent.click(submitButton);

    expect(onComplete).to.have.been.called();
  });
});
