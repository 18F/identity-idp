import React from 'react';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import sinon from 'sinon';
import FormSteps, {
  getStepIndexByName,
} from '@18f/identity-document-capture/components/form-steps';
import render from '../../../support/render';

describe('document-capture/components/form-steps', () => {
  const STEPS = [
    { name: 'first', title: 'First Title', form: () => <span>First</span> },
    {
      name: 'second',
      title: 'Second Title',
      form: ({ value = {}, errors = [], onChange, registerField }) => (
        <>
          <input
            aria-label="Second Input One"
            ref={registerField('secondInputOne', { isRequired: true })}
            value={value.secondInputOne || ''}
            data-is-error={errors.some(({ field }) => field === 'secondInputOne') || undefined}
            onChange={(event) => {
              onChange({ changed: true });
              onChange({ secondInputOne: event.target.value });
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
        </>
      ),
    },
    { name: 'last', title: 'Last Title', form: () => <span>Last</span> },
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
    expect(getByLabelText('Second Input One').value).to.equal('one');
    expect(getByLabelText('Second Input Two').value).to.equal('two');
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
    const input = getByLabelText('Second Input One');

    expect(input.value).to.equal('prefilled');
  });

  it('prevents submission if step is invalid', async () => {
    const { getByText, getByLabelText, container } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.continue'));

    expect(window.location.hash).to.equal('#step=second');
    expect(document.activeElement).to.equal(getByLabelText('Second Input One'));
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(2);

    await userEvent.type(document.activeElement, 'one');
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(1);

    userEvent.click(getByText('forms.buttons.continue'));
    expect(document.activeElement).to.equal(getByLabelText('Second Input Two'));
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(1);

    await userEvent.type(document.activeElement, 'two');
    expect(container.querySelectorAll('[data-is-error]')).to.have.lengthOf(0);
    userEvent.click(getByText('forms.buttons.continue'));

    expect(document.activeElement).to.equal(getByText('Last Title'));
  });

  it('renders with optional footer', () => {
    const steps = [
      {
        name: 'one',
        title: 'Step One',
        form: () => <span>Form Fields</span>,
        footer: () => <span>Footer</span>,
      },
    ];
    const { getByText } = render(<FormSteps steps={steps} />);

    expect(getByText('Footer')).to.be.ok();
  });
});
