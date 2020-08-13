import React from 'react';
import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import FormSteps, {
  isStepValid,
  getStepIndexByName,
  getLastValidStepIndex,
} from '@18f/identity-document-capture/components/form-steps';
import render from '../../../support/render';

describe('document-capture/components/form-steps', () => {
  const STEPS = [
    { name: 'first', title: 'First Title', component: () => <span>First</span> },
    {
      name: 'second',
      title: 'Second Title',
      component: ({ value = {}, onChange }) => (
        // eslint-disable-next-line jsx-a11y/label-has-associated-control
        <label>
          Second
          <input
            value={value.second || ''}
            onChange={(event) => {
              onChange({ changed: true });
              onChange({ second: event.target.value });
            }}
          />
        </label>
      ),
      isValid: (value) => Boolean(value.second),
    },
    { name: 'last', title: 'Last Title', component: () => <span>Last</span> },
  ];

  let originalHash;

  beforeEach(() => {
    originalHash = window.location.hash;
  });

  afterEach(() => {
    window.location.hash = originalHash;
  });

  describe('isStepValid', () => {
    it('defaults to true if there is no specified validity function', () => {
      const step = { name: 'example' };

      const result = isStepValid(step, {});

      expect(result).to.be.true();
    });

    it('returns the result of the validity function given form values', () => {
      const step = { name: 'example', isValid: (value) => value.ok };

      const result = isStepValid(step, { ok: false });

      expect(result).to.be.false();
    });
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

  describe('getLastValidStepIndex', () => {
    it('returns -1 if array is empty', () => {
      const result = getLastValidStepIndex([], {});

      expect(result).to.be.equal(-1);
    });

    it('returns -1 if all steps are invalid', () => {
      const steps = [...STEPS].map((step) => ({ ...step, isValid: () => false }));
      const result = getLastValidStepIndex(steps, {});

      expect(result).to.be.equal(-1);
    });

    it('returns index of the last valid step', () => {
      const result = getLastValidStepIndex(STEPS, { second: 'valid' });

      expect(result).to.be.equal(2);
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

    expect(getByText('Second')).to.be.ok();
  });

  it('renders continue button until at last step', () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));

    expect(getByText('forms.buttons.continue')).to.be.ok();
  });

  it('renders submit button at last step', () => {
    const { getByText, getByRole } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.type(getByRole('textbox'), 'val');
    userEvent.click(getByText('forms.buttons.continue'));

    expect(getByText('forms.buttons.submit.default')).to.be.ok();
  });

  it('submits with form values', () => {
    const onComplete = sinon.spy();
    const { getByText, getByRole } = render(<FormSteps steps={STEPS} onComplete={onComplete} />);

    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.type(getByRole('textbox'), 'val');
    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.submit.default'));

    expect(onComplete.getCall(0).args[0]).to.eql({
      second: 'val',
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
    const { getByText, findByText, getByRole } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.type(getByRole('textbox'), 'val');

    window.history.back();

    expect(await findByText('First')).to.be.ok();
    expect(window.location.hash).to.equal('');

    window.history.forward();

    expect(await findByText('Second')).to.be.ok();
    expect(getByRole('textbox').value).to.equal('val');
    expect(window.location.hash).to.equal('#step=second');
  });

  it('clear URL parameter after submission', (done) => {
    const onComplete = sinon.spy(() => {
      expect(window.location.hash).to.equal('');

      done();
    });
    const { getByText, getByRole } = render(<FormSteps steps={STEPS} onComplete={onComplete} />);

    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.type(getByRole('textbox'), 'val');
    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.submit.default'));
  });

  it('shifts focus to next heading on step change', async () => {
    const { getByText } = render(<FormSteps steps={STEPS} />);

    userEvent.click(getByText('forms.buttons.continue'));

    expect(document.activeElement).to.equal(getByText('Second Title'));
  });

  it("doesn't assign focus on mount", async () => {
    const { activeElement: originalActiveElement } = document;
    render(<FormSteps steps={STEPS} />);
    expect(document.activeElement).to.equal(originalActiveElement);
  });

  it('validates step completion', () => {
    window.location.hash = '#step=last';

    render(<FormSteps steps={STEPS} />);

    expect(window.location.hash).to.equal('#step=second');
  });
});
