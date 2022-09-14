import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { FormSteps } from '@18f/identity-form-steps';
import * as analytics from '@18f/identity-analytics';
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

  const sandbox = sinon.createSandbox();

  beforeEach(() => {
    sandbox.spy(analytics, 'trackEvent');
  });

  afterEach(() => {
    sandbox.restore();
  });

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

  it('calls trackEvent when user dismisses modal by pressing "Back" button', async () => {
    const toPreviousStep = sinon.spy();

    const { getByText } = render(
      <PersonalKeyConfirmStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
    );

    await userEvent.click(getByText('forms.buttons.back'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: hide personal key modal');
  });

  it('passes the value the user has entered to this point to the child PersonalKeyInput', () => {
    const props = {
      ...DEFAULT_PROPS,
      value: {
        personalKey: '',
        personalKeyConfirm: '1234-asdf',
      },
      toPreviousStep: () => {},
    };

    const { getByRole } = render(<PersonalKeyConfirmStep {...props} />);

    const input = getByRole('textbox') as HTMLInputElement;

    expect(input.value).to.equal('1234-asdf-');
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
    const continueButton = getAllByText('forms.buttons.continue')[1];
    await userEvent.click(continueButton);

    expect(onComplete).not.to.have.been.called();
    expect(container.ownerDocument.activeElement).to.equal(input);
    let errorMessage = document.getElementById(input.getAttribute('aria-describedby')!);
    expect(errorMessage!.textContent).to.equal('users.personal_key.confirmation_error');

    await userEvent.type(input, '0000-0000-0000-000');
    errorMessage = document.getElementById(input.getAttribute('aria-describedby')!);
    expect(errorMessage?.style.display === 'none').to.be.true();
    await userEvent.type(input, '{Enter}');
    expect(onComplete).not.to.have.been.called();
    errorMessage = document.getElementById(input.getAttribute('aria-describedby')!);
    expect(errorMessage!.textContent).to.equal('users.personal_key.confirmation_error');

    await userEvent.type(input, '0');

    await userEvent.type(input, '{Enter}');
    expect(onComplete).to.have.been.calledOnce();

    await userEvent.click(continueButton);
    expect(onComplete).to.have.been.calledTwice();
  });
});
