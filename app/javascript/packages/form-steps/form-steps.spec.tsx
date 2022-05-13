import { useContext } from 'react';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import sinon from 'sinon';
import { PageHeading } from '@18f/identity-components';
import * as analytics from '@18f/identity-analytics';
import FormSteps, { FormStepComponentProps, getStepIndexByName } from './form-steps';
import FormError from './form-error';
import FormStepsContext from './form-steps-context';
import FormStepsButton from './form-steps-button';
import type { FormStep } from './form-steps';

interface StepValues {
  secondInputOne?: string;

  secondInputTwo?: string;

  changed?: boolean;
}

const sleep = (ms: number) => () => new Promise<void>((resolve) => setTimeout(resolve, ms));

describe('FormSteps', () => {
  const sandbox = sinon.createSandbox();

  beforeEach(() => {
    sandbox.spy(analytics, 'trackEvent');
  });

  afterEach(() => {
    sandbox.restore();
    if (sandbox.clock) {
      sandbox.clock.restore();
    }
  });

  const STEPS: FormStep[] = [
    {
      name: 'first',
      title: 'First Title',
      form: ({ errors }) => (
        <>
          <PageHeading>First Title</PageHeading>
          <span>First</span>
          <FormStepsButton.Continue />
          <span data-testid="context-value">{JSON.stringify(useContext(FormStepsContext))}</span>
          <span>Errors: {errors.map(({ error }) => error.message).join(',')}</span>
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
        toPreviousStep,
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
          <button type="button" onClick={toPreviousStep}>
            Back
          </button>
          <button type="button" onClick={() => onError(new Error())}>
            Create Step Error
          </button>
          <FormStepsButton.Continue />
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
          <FormStepsButton.Submit />
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

  it('sets the browser page title using titleFormat', () => {
    render(<FormSteps steps={STEPS} titleFormat="%{step} - Example" />);

    expect(document.title).to.equal('First Title - Example');
  });

  it('renders continue button at first step', () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    expect(getByText('forms.buttons.continue')).to.be.ok();
  });

  it('proceeds after resolving step submit implementation, if provided', async () => {
    sandbox.useFakeTimers();
    const steps = [{ ...STEPS[0], submit: sleep(1000) }, STEPS[1]];
    const { getByText } = render(<FormSteps steps={steps} />);

    const continueButton = getByText('forms.buttons.continue');
    await userEvent.click(continueButton, { advanceTimers: sandbox.clock.tick });

    expect(getByText('First Title')).to.be.ok();
    expect(
      continueButton
        .closest('lg-spinner-button')!
        .classList.contains('spinner-button--spinner-active'),
    ).to.be.true();
    await sandbox.clock.tickAsync(1000);

    expect(getByText('Second Title')).to.be.ok();
  });

  it('uses submit implementation return value as patch to form values', async () => {
    const steps = [
      { ...STEPS[0], submit: () => Promise.resolve({ secondInputOne: 'received' }) },
      STEPS[1],
    ];
    const { getByText, findByDisplayValue } = render(<FormSteps steps={steps} />);

    const continueButton = getByText('forms.buttons.continue');
    await userEvent.click(continueButton);

    expect(await findByDisplayValue('received')).to.be.ok();
  });

  it('does not proceed if step submit implementation throws an error', async () => {
    sandbox.useFakeTimers();
    const steps = [
      {
        ...STEPS[0],
        submit: () =>
          sleep(1000)().then(() => {
            throw new Error('oops');
          }),
      },
      STEPS[1],
    ];
    const { getByText } = render(<FormSteps steps={steps} />);

    const continueButton = getByText('forms.buttons.continue');
    await userEvent.click(continueButton, { advanceTimers: sandbox.clock.tick });

    await sandbox.clock.tickAsync(1000);

    expect(getByText('Errors: oops')).to.be.ok();
  });

  it('renders the active step', async () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    await userEvent.click(getByText('forms.buttons.continue'));

    expect(getByText('Second Title')).to.be.ok();
  });

  it('calls onStepChange callback on step change', async () => {
    const onStepChange = sinon.spy();
    const { getByText } = render(<FormSteps steps={STEPS} onStepChange={onStepChange} />);

    await userEvent.click(getByText('forms.buttons.continue'));

    expect(onStepChange.calledOnce).to.be.true();
  });

  it('does not call onStepChange if step does not progress due to validation error', async () => {
    const onStepChange = sinon.spy();
    const { getByText } = render(<FormSteps steps={STEPS} onStepChange={onStepChange} />);

    await userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.click(getByText('forms.buttons.continue'));

    expect(onStepChange.callCount).to.equal(1);
  });

  it('calls onChange with updated form values', async () => {
    const onChange = sinon.spy();
    const { getByText, getByLabelText } = render(<FormSteps steps={STEPS} onChange={onChange} />);

    await userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.type(getByLabelText('Second Input One'), 'one');

    expect(onChange).to.have.been.calledWith({ changed: true, secondInputOne: 'o' });
    expect(onChange).to.have.been.calledWith({ changed: true, secondInputOne: 'on' });
    expect(onChange).to.have.been.calledWith({ changed: true, secondInputOne: 'one' });
  });

  it('submits with form values', async () => {
    const onComplete = sinon.spy();
    const { getByText, getByLabelText } = render(
      <FormSteps steps={STEPS} onComplete={onComplete} />,
    );

    await userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.type(getByLabelText('Second Input One'), 'one');
    await userEvent.type(getByLabelText('Second Input Two'), 'two');
    await userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.click(getByText('forms.buttons.submit.default'));

    expect(onComplete.getCall(0).args[0]).to.eql({
      secondInputOne: 'one',
      secondInputTwo: 'two',
      changed: true,
    });
  });

  it('will submit the form by enter press in an input', async () => {
    const onComplete = sinon.spy();
    const { getByText, getByLabelText } = render(
      <FormSteps steps={STEPS} onComplete={onComplete} />,
    );

    await userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.type(getByLabelText('Second Input One'), 'one');
    await userEvent.type(getByLabelText('Second Input Two'), 'two{Enter}');

    expect(getByText('Last Title')).to.be.ok();
  });

  it('prompts on navigate if values have been assigned', async () => {
    const { getByText, getByLabelText } = render(<FormSteps steps={STEPS} />);

    await userEvent.click(getByText('forms.buttons.continue'));
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

  context('promptOnNavigate prop is set to false', () => {
    it('does not prompt on navigate', () => {
      render(<FormSteps steps={STEPS} promptOnNavigate={false} />);

      const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
      window.dispatchEvent(event);

      expect(event.defaultPrevented).to.be.false();
      expect(event.returnValue).to.be.true();
    });
  });

  it('pushes step to URL', async () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    expect(window.location.hash).to.equal('');

    await userEvent.click(getByText('forms.buttons.continue'));

    expect(window.location.hash).to.equal('#second');
  });

  it('syncs step by history events', async () => {
    const { getByText, findByText, getByLabelText } = render(<FormSteps steps={STEPS} />);

    await userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.type(getByLabelText('Second Input One'), 'one');
    await userEvent.type(getByLabelText('Second Input Two'), 'two');

    window.history.back();

    expect(await findByText('First Title')).to.be.ok();
    expect(window.location.hash).to.equal('');

    window.history.forward();

    expect(await findByText('Second Title')).to.be.ok();
    expect((getByLabelText('Second Input One') as HTMLInputElement).value).to.equal('one');
    expect((getByLabelText('Second Input Two') as HTMLInputElement).value).to.equal('two');
    expect(window.location.hash).to.equal('#second');
  });

  it('shifts focus to next heading on step change', async () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    await userEvent.click(getByText('forms.buttons.continue'));

    expect(document.activeElement).to.equal(getByText('Second Title'));
  });

  it("doesn't assign focus on mount", () => {
    const { activeElement: originalActiveElement } = document;
    render(<FormSteps steps={STEPS} />);
    expect(document.activeElement).to.equal(originalActiveElement);
  });

  it('optionally auto-focuses', () => {
    const { getByText } = render(<FormSteps steps={STEPS} autoFocus />);

    expect(document.activeElement).to.equal(getByText('First Title'));
  });

  it('accepts initial values', async () => {
    const { getByText, getByLabelText } = render(
      <FormSteps steps={STEPS} initialValues={{ secondInputOne: 'prefilled' }} />,
    );

    await userEvent.click(getByText('forms.buttons.continue'));
    const input = getByLabelText('Second Input One') as HTMLInputElement;

    expect(input.value).to.equal('prefilled');
  });

  it('prevents submission if step is invalid', async () => {
    const { getByText, getByLabelText, container } = render(<FormSteps steps={STEPS} />);

    await userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.click(getByText('forms.buttons.continue'));

    expect(window.location.hash).to.equal('#second');
    expect(document.activeElement).to.equal(getByLabelText('Second Input One'));
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(2);

    await userEvent.type(document.activeElement as HTMLInputElement, 'one');
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(1);

    await userEvent.click(getByText('forms.buttons.continue'));
    expect(document.activeElement).to.equal(getByLabelText('Second Input Two'));
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(1);

    await userEvent.type(document.activeElement as HTMLInputElement, 'two');
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(0);
    await userEvent.click(getByText('forms.buttons.continue'));

    expect(document.activeElement).to.equal(getByText('Last Title'));
  });

  it('respects native custom input validity', async () => {
    const { getByRole } = render(<FormSteps steps={STEPS} />);

    await userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));
    const inputOne = getByRole('textbox', { name: 'Second Input One' }) as HTMLInputElement;
    const inputTwo = getByRole('textbox', { name: 'Second Input Two' }) as HTMLInputElement;

    // Make inputs otherwise valid.
    await userEvent.type(inputOne, 'one');
    await userEvent.type(inputTwo, 'two');

    // Add custom validity error.
    const checkValidity = () => {
      inputOne.setCustomValidity('Custom Error');
      return false;
    };
    inputOne.reportValidity = checkValidity;
    inputOne.checkValidity = checkValidity;

    await userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));

    expect(inputOne.hasAttribute('data-is-error')).to.be.true();
    expect(document.activeElement).to.equal(inputOne);
  });

  it('supports ref assignment to arbitrary (non-input) elements', async () => {
    const onComplete = sandbox.stub();
    const { getByRole } = render(
      <FormSteps
        onComplete={onComplete}
        steps={[
          {
            name: 'first',
            form({ registerField }) {
              return (
                <div ref={registerField('element')}>
                  <FormStepsButton.Submit />
                </div>
              );
            },
          },
        ]}
      />,
    );

    await userEvent.click(getByRole('button', { name: 'forms.buttons.submit.default' }));

    expect(onComplete).to.have.been.called();
  });

  it('distinguishes empty errors from progressive error removal', async () => {
    const { getByText, getByLabelText, container } = render(<FormSteps steps={STEPS} />);

    await userEvent.click(getByText('forms.buttons.continue'));

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
        initialValues={{
          secondInputTwo: 'two',
        }}
        initialActiveErrors={[
          {
            field: 'unknown',
            error: new FormError(),
          },
          {
            field: 'secondInputOne',
            error: new FormError(),
          },
          {
            field: 'secondInputTwo',
            error: new FormError(),
          },
        ]}
        onComplete={onComplete}
      />,
    );

    // Field associated errors are handled by the field.
    const inputOne = getByLabelText('Second Input One');
    const inputTwo = getByLabelText('Second Input Two');
    expect(inputOne.matches('[data-is-error]')).to.be.true();
    expect(inputTwo.matches('[data-is-error]')).to.be.true();

    // Attempting to submit without adjusting field value does not submit and shows error.
    await userEvent.click(getByText('forms.buttons.continue'));
    expect(onComplete.called).to.be.false();
    await waitFor(() => expect(document.activeElement).to.equal(inputOne));

    // Changing the value for the first field should unset the first error.
    await userEvent.type(inputOne, 'one');
    expect(inputOne.matches('[data-is-error]')).to.be.false();
    expect(inputTwo.matches('[data-is-error]')).to.be.true();

    // Default required validation should still happen and take the place of any unknown errors.
    await userEvent.click(getByText('forms.buttons.continue'));
    expect(onComplete.called).to.be.false();
    await waitFor(() => expect(document.activeElement).to.equal(inputTwo));
    expect(inputOne.matches('[data-is-error]')).to.be.false();
    expect(inputTwo.matches('[data-is-error]')).to.be.true();
    expect(() => getByRole('alert')).to.throw();

    // Changing the value for the second field should unset the second error.
    await userEvent.type(inputTwo, 'two');
    expect(inputOne.matches('[data-is-error]')).to.be.false();
    expect(inputTwo.matches('[data-is-error]')).to.be.false();

    // The user can submit once all errors have been resolved.
    await userEvent.click(getByText('forms.buttons.continue'));
    expect(onComplete.calledOnce).to.be.true();
  });

  it('renders field-emitted errors', async () => {
    const steps = [STEPS[1]];

    const { getByLabelText } = render(<FormSteps steps={steps} />);
    const inputOne = getByLabelText('Second Input One') as HTMLInputElement;
    inputOne.setCustomValidity('uh oh');
    await userEvent.type(inputOne, 'one');

    expect(inputOne.hasAttribute('data-is-error')).to.be.true();
  });

  it('renders and moves focus to step errors', async () => {
    const steps = [STEPS[1]];

    const { getByRole } = render(<FormSteps steps={steps} />);
    const button = getByRole('button', { name: 'Create Step Error' });
    await await userEvent.click(button);

    expect(getByRole('alert')).to.equal(document.activeElement);
  });

  it('provides context', async () => {
    const { getByTestId, getByRole, getByLabelText } = render(<FormSteps steps={STEPS} />);

    expect(JSON.parse(getByTestId('context-value').textContent!)).to.deep.equal({
      isLastStep: false,
      isSubmitting: false,
    });

    await userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));
    expect(window.location.hash).to.equal('#second');

    // Trigger validation errors on second step.
    await userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));
    expect(window.location.hash).to.equal('#second');
    expect(JSON.parse(getByTestId('context-value').textContent!)).to.deep.equal({
      isLastStep: false,
      isSubmitting: false,
    });

    await userEvent.type(getByLabelText('Second Input One'), 'one');
    await userEvent.type(getByLabelText('Second Input Two'), 'two');

    await userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));
    expect(window.location.hash).to.equal('#last');
    expect(JSON.parse(getByTestId('context-value').textContent!)).to.deep.equal({
      isLastStep: true,
      isSubmitting: false,
    });
  });

  it('allows context consumers to trigger content reset', async () => {
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
    await userEvent.click(getByRole('button', { name: 'Replace' }));
    sandbox.spy(window.history, 'pushState');

    expect(window.scrollY).to.equal(0);
    expect(document.activeElement).to.equal(getByRole('heading', { name: 'Content Title' }));
    expect(window.history.pushState).not.to.have.been.called();
  });

  it('provides the step implementation the option to navigate to the previous step', async () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    await userEvent.click(getByText('forms.buttons.continue'));
    await userEvent.click(getByText('Back'));

    expect(getByText('First Title')).to.be.ok();
  });

  it('supports starting at a specific step', () => {
    const { getByText } = render(<FormSteps steps={STEPS} initialStep="second" />);

    expect(getByText('Second Title')).to.be.ok();
  });
});
