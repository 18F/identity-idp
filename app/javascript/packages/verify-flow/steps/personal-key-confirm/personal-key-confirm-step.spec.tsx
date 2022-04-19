import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
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

  it('allows the user to return to the previous step', () => {
    const toPreviousStep = sinon.spy();
    const { getByText } = render(
      <PersonalKeyConfirmStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
    );

    userEvent.click(getByText('forms.buttons.back'));

    expect(toPreviousStep).to.have.been.called();
  });
});
