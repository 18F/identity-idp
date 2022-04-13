import { useContext } from 'react';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import sinon from 'sinon';
import PageHeading from '@18f/identity-document-capture/components/page-heading';
import FormSteps, { FormStepComponentProps, getStepIndexByName } from './form-steps';
import FormError from './form-error';
import FormStepsContext from './form-steps-context';
import FormStepsContinueButton from './form-steps-continue-button';

interface StepValues {
  secondInputOne?: string;

  secondInputTwo?: string;

  changed?: boolean;
}

describe('FormSteps', () => {
  const { spy } = sinon.createSandbox();

  const STEPS = [
    {
      name: 'first',
      form: () => (
        <>
          <PageHeading>First Title</PageHeading>
          <span>First</span>
          <FormStepsContinueButton />
          <span data-testid="context-value">{JSON.stringify(useContext(FormStepsContext))}</span>
        </>
      ),
    },
    {
      name: 'second',
      form: ({
        value = {},
        errors = [],
        onChange,
        onError,
        registerField,
      }: FormStepComponentProps<StepValues>) => (
        <>
          <PageHeading>Second Title</PageHeading>
          <input
            aria-label="Second Input One"
            ref={registerField('secondInputOne', { isRequired: true })}
            value={value.secondInputOne || ''}
            data-is-error={errors.some(({ field }) => field === 'secondInputOne') || undefined}
            onChange={(event) => {
              if (event.target.validationMessage) {
                onError(new Error(event.target.validationMessage), { field: 'secondInputOne' });
              } else {
                onChange({ changed: true });
                onChange({ secondInputOne: event.target.value });
              }
            }}
          />
          <input
            aria-label="Second Input Two"
            ref={registerField('secondInputTwo', { isRequired: true })}
            value={value.secondInputTwo || ''}
            data-is-error={errors.some(({ field }) => field === 'secondInputTwo') || undefined}
            onChange={(event) => {
              onChange({ changed: true });
              onChange({ secondInputTwo: event.target.value });
            }}
          />
          <button type="button" onClick={() => onError(new Error())}>
            Create Step Error
          </button>
          <FormStepsContinueButton />
          <span data-testid="context-value">{JSON.stringify(useContext(FormStepsContext))}</span>
        </>
      ),
    },
    {
      name: 'last',
      form: () => (
        <>
          <PageHeading>Last Title</PageHeading>
          <span>Last</span>
          <FormStepsContinueButton />
          <span data-testid="context-value">{JSON.stringify(useContext(FormStepsContext))}</span>
        </>
      ),
    },
  ];

  let originalHash;

  beforeEach(() => {
    originalHash = window.location.hash;
  });

  afterEach(() => {
    window.location.hash = originalHash;
  });

  describe('getStepIndexByName', () => {
    it('returns -1 if no step by name', () => {
      const result = getStepIndexByName(STEPS, 'third');

      expect(result).to.be.equal(-1);
    });

    it('returns index of step by name', () => {
      const result = getStepIndexByName(STEPS, 'second');

      expect(result).to.be.equal(1);
    });
  });

  it('renders nothing if given empty steps array', () => {
    const { container } = render(<FormSteps steps={[]} />);

    expect(container.childNodes).to.have.lengthOf(0);
  });

  it('renders the first step initially', () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    expect(getByText('First')).to.be.ok();
  });

  it('renders continue button at first step', () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    expect(getByText('forms.buttons.continue')).to.be.ok();
  });

  it('renders the active step', () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));

    expect(getByText('Second Title')).to.be.ok();
  });

  it('renders continue button until at last step', () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));

    expect(getByText('forms.buttons.continue')).to.be.ok();
  });

  it('calls onStepChange callback on step change', () => {
    const onStepChange = sinon.spy();
    const { getByText } = render(<FormSteps steps={STEPS} onStepChange={onStepChange} />);

    userEvent.click(getByText('forms.buttons.continue'));

    expect(onStepChange.calledOnce).to.be.true();
  });

  it('does not call onStepChange if step does not progress due to validation error', () => {
    const onStepChange = sinon.spy();
    const { getByText } = render(<FormSteps steps={STEPS} onStepChange={onStepChange} />);

    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.continue'));

    expect(onStepChange.callCount).to.equal(1);
  });

  it('renders submit button at last step', async () => {
    const { getByText, getByLabelText } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.type(getByLabelText('Second Input One'), 'one');
    await userEvent.type(getByLabelText('Second Input Two'), 'two');
    userEvent.click(getByText('forms.buttons.continue'));

    expect(getByText('forms.buttons.submit.default')).to.be.ok();
  });

  it('submits with form values', async () => {
    const onComplete = sinon.spy();
    const { getByText, getByLabelText } = render(
      <FormSteps steps={STEPS} onComplete={onComplete} />,
    );

    userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.type(getByLabelText('Second Input One'), 'one');
    await userEvent.type(getByLabelText('Second Input Two'), 'two');
    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.submit.default'));

    expect(onComplete.getCall(0).args[0]).to.eql({
      secondInputOne: 'one',
      secondInputTwo: 'two',
      changed: true,
    });
  });

  it('prompts on navigate if values have been assigned', async () => {
    const { getByText, getByLabelText } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.type(getByLabelText('Second Input One'), 'one');

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);

    expect(event.defaultPrevented).to.be.true();
    expect(event.returnValue).to.be.false();
  });

  it('does not prompt on navigate if no values have been assigned', () => {
    render(<FormSteps steps={STEPS} />);

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);

    expect(event.defaultPrevented).to.be.false();
    expect(event.returnValue).to.be.true();
  });

  it('pushes step to URL', () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    expect(window.location.hash).to.equal('');

    userEvent.click(getByText('forms.buttons.continue'));

    expect(window.location.hash).to.equal('#step=second');
  });

  it('syncs step by history events', async () => {
    const { getByText, findByText, getByLabelText } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.type(getByLabelText('Second Input One'), 'one');
    await userEvent.type(getByLabelText('Second Input Two'), 'two');

    window.history.back();

    expect(await findByText('First Title')).to.be.ok();
    expect(window.location.hash).to.equal('');

    window.history.forward();

    expect(await findByText('Second Title')).to.be.ok();
    expect((getByLabelText('Second Input One') as HTMLInputElement).value).to.equal('one');
    expect((getByLabelText('Second Input Two') as HTMLInputElement).value).to.equal('two');
    expect(window.location.hash).to.equal('#step=second');
  });

  it('clear URL parameter after submission', async () => {
    const onComplete = sinon.spy();
    const { getByText, getByLabelText } = render(
      <FormSteps steps={STEPS} onComplete={onComplete} />,
    );

    userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.type(getByLabelText('Second Input One'), 'one');
    await userEvent.type(getByLabelText('Second Input Two'), 'two');
    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.submit.default'));
    await waitFor(() => expect(onComplete.calledOnce).to.be.true());
    expect(window.location.hash).to.equal('');
  });

  it('shifts focus to next heading on step change', () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));

    expect(document.activeElement).to.equal(getByText('Second Title'));
  });

  it("doesn't assign focus on mount", () => {
    const { activeElement: originalActiveElement } = document;
    render(<FormSteps steps={STEPS} />);
    expect(document.activeElement).to.equal(originalActiveElement);
  });

  it('resets to first step at mount', () => {
    window.location.hash = '#step=last';

    render(<FormSteps steps={STEPS} />);

    expect(window.location.hash).to.equal('');
  });

  it('optionally auto-focuses', () => {
    const { getByText } = render(<FormSteps steps={STEPS} autoFocus />);

    expect(document.activeElement).to.equal(getByText('First Title'));
  });

  it('accepts initial values', () => {
    const { getByText, getByLabelText } = render(
      <FormSteps steps={STEPS} initialValues={{ secondInputOne: 'prefilled' }} />,
    );

    userEvent.click(getByText('forms.buttons.continue'));
    const input = getByLabelText('Second Input One') as HTMLInputElement;

    expect(input.value).to.equal('prefilled');
  });

  it('prevents submission if step is invalid', async () => {
    const { getByText, getByLabelText, container } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.continue'));

    expect(window.location.hash).to.equal('#step=second');
    expect(document.activeElement).to.equal(getByLabelText('Second Input One'));
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(2);

    await userEvent.type(document.activeElement as HTMLInputElement, 'one');
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(1);

    userEvent.click(getByText('forms.buttons.continue'));
    expect(document.activeElement).to.equal(getByLabelText('Second Input Two'));
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(1);

    await userEvent.type(document.activeElement as HTMLInputElement, 'two');
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(0);
    userEvent.click(getByText('forms.buttons.continue'));

    expect(document.activeElement).to.equal(getByText('Last Title'));
  });

  it('distinguishes empty errors from progressive error removal', async () => {
    const { getByText, getByLabelText, container } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));

    await userEvent.type(getByLabelText('Second Input One'), 'one');
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(0);
  });

  it('renders with initial active errors', async () => {
    // Assumption: initialActiveErrors are only shown in combination with a flow of a single step.
    const steps = [STEPS[1]];
    const onComplete = sinon.spy();

    const { getByLabelText, getByText, getByRole } = render(
      <FormSteps
        steps={steps}
        initialActiveErrors={[
          {
            field: 'unknown',
            error: new FormError(),
          },
          {
            field: 'secondInputOne',
            error: new FormError(),
          },
        ]}
        onComplete={onComplete}
      />,
    );

    // Field associated errors are handled by the field. There should only be one.
    const inputOne = getByLabelText('Second Input One');
    const inputTwo = getByLabelText('Second Input Two');
    expect(inputOne.matches('[data-is-error]')).to.be.true();
    expect(inputTwo.matches('[data-is-error]')).to.be.false();

    // Attempting to submit without adjusting field value does not submit and shows error.
    userEvent.click(getByText('forms.buttons.submit.default'));
    expect(onComplete.called).to.be.false();
    await waitFor(() => expect(document.activeElement).to.equal(inputOne));

    // Changing the value for the field should unset the error.
    await userEvent.type(inputOne, 'one');
    expect(inputOne.matches('[data-is-error]')).to.be.false();
    expect(inputTwo.matches('[data-is-error]')).to.be.false();

    // Default required validation should still happen and take the place of any unknown errors.
    userEvent.click(getByText('forms.buttons.submit.default'));
    expect(onComplete.called).to.be.false();
    await waitFor(() => expect(document.activeElement).to.equal(inputTwo));
    expect(inputOne.matches('[data-is-error]')).to.be.false();
    expect(inputTwo.matches('[data-is-error]')).to.be.true();
    expect(() => getByRole('alert')).to.throw();

    // Changing the value for the field should unset the error.
    await userEvent.type(inputTwo, 'two');
    expect(inputOne.matches('[data-is-error]')).to.be.false();
    expect(inputTwo.matches('[data-is-error]')).to.be.false();

    // The user can submit once all errors have been resolved.
    userEvent.click(getByText('forms.buttons.submit.default'));
    expect(onComplete.calledOnce).to.be.true();
  });

  it('renders field-emitted errors', () => {
    const steps = [STEPS[1]];

    const { getByLabelText } = render(<FormSteps steps={steps} />);
    const inputOne = getByLabelText('Second Input One') as HTMLInputElement;
    inputOne.setCustomValidity('uh oh');
    userEvent.type(inputOne, 'one');

    expect(inputOne.hasAttribute('data-is-error')).to.be.true();
  });

  it('renders and moves focus to step errors', () => {
    const steps = [STEPS[1]];

    const { getByRole } = render(<FormSteps steps={steps} />);
    const button = getByRole('button', { name: 'Create Step Error' });
    userEvent.click(button);

    expect(getByRole('alert')).to.equal(document.activeElement);
  });

  it('provides context', () => {
    const { getByTestId, getByRole, getByLabelText } = render(<FormSteps steps={STEPS} />);

    expect(JSON.parse(getByTestId('context-value').textContent!)).to.deep.equal({
      isLastStep: false,
    });

    userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));
    expect(window.location.hash).to.equal('#step=second');

    // Trigger validation errors on second step.
    userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));
    expect(window.location.hash).to.equal('#step=second');
    expect(JSON.parse(getByTestId('context-value').textContent!)).to.deep.equal({
      isLastStep: false,
    });

    userEvent.type(getByLabelText('Second Input One'), 'one');
    userEvent.type(getByLabelText('Second Input Two'), 'two');

    userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));
    expect(window.location.hash).to.equal('#step=last');
    expect(JSON.parse(getByTestId('context-value').textContent!)).to.deep.equal({
      isLastStep: true,
    });
  });

  it('allows context consumers to trigger content reset', () => {
    const { getByRole } = render(
      <FormSteps
        steps={[
          {
            name: 'content-reset',
            form: () => (
              <>
                <h1>Content Title</h1>
                <button type="button" onClick={useContext(FormStepsContext).onPageTransition}>
                  Replace
                </button>
              </>
            ),
          },
        ]}
      />,
    );

    window.scrollY = 100;
    userEvent.click(getByRole('button', { name: 'Replace' }));
    spy(window.history, 'pushState');

    expect(window.scrollY).to.equal(0);
    expect(document.activeElement).to.equal(getByRole('heading', { name: 'Content Title' }));
    expect(window.history.pushState).not.to.have.been.called();
  });
});
