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

  it('allows the user to continue only with a correct value', async () => {
    const onComplete = sinon.spy();
    const { getByLabelText, getAllByText, container } = render(
      <FormSteps
        steps={[{ name: 'personal_key_confirm', form: PersonalKeyConfirmStep }]}
        initialValues={{ personalKey: '0000-0000-0000-0000' }}
        onComplete={onComplete}
      />,
    );

    const input = getByLabelText('forms.personal_key.confirmation_label');
    const submitButton = getAllByText('forms.buttons.submit.default')[1];
    userEvent.click(submitButton);

    expect(onComplete).not.to.have.been.called();
    expect(container.ownerDocument.activeElement).to.equal(input);
    let errorMessage = document.getElementById(input.getAttribute('aria-describedby')!);
    expect(errorMessage!.textContent).to.equal('users.personal_key.confirmation_error');

    await userEvent.type(input, '0000-0000-0000-000');
    errorMessage = document.getElementById(input.getAttribute('aria-describedby')!);
    expect(errorMessage).to.not.exist();
    await userEvent.type(input, '{enter}');
    expect(onComplete).not.to.have.been.called();
    errorMessage = document.getElementById(input.getAttribute('aria-describedby')!);
    expect(errorMessage!.textContent).to.equal('users.personal_key.confirmation_error');

    await userEvent.type(input, '0');

    input.closest('form')!.addEventListener(
      'submit',
      function (event) {
        // A form should not emit a submit event if any of its fields are invalid, but either JSDOM
        // or @testing-library/user-event is not considering this, and happily allows submission. We
        // emulate this behavior to match the expected browser experience.
        //
        // "If the submitter element's no-validate state is false, then interactively validate the
        //  constraints of form and examine the result. If the result is negative (i.e., the
        //  constraint validation concluded that there were invalid fields and probably informed the
        //  user of this), then: [...] Set form's firing submission events to false. [...] Return."
        //
        // https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#form-submission-algorithm

        if (!this.noValidate && !this.checkValidity()) {
          event.preventDefault();
          event.stopImmediatePropagation();
        }
      },
      true,
    );

    await userEvent.type(input, '{enter}');
    expect(onComplete).to.have.been.calledOnce();

    userEvent.click(submitButton);
    expect(onComplete).to.have.been.calledTwice();
  });
});
