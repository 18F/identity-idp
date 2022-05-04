import sinon from 'sinon';
import { render, fireEvent, createEvent } from '@testing-library/react';
import { usePropertyValue } from '@18f/identity-test-helpers';
import PasswordConfirmStep from './password-confirm-step';

describe('PasswordConfirm', () => {
  const sandbox = sinon.createSandbox();
  const DEFAULT_PROPS = {
    onChange() {},
    onError() {},
    errors: [],
    toPreviousStep() {},
    registerField: () => () => {},
    unknownFieldErrors: [],
    value: { passwordConfirm: '' },
  };

  beforeEach(() => {
    sandbox.spy(analytics, 'trackEvent');
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('it has a collapsed accordion', async () => {
    const toPreviousStep = sinon.spy();
    const { getByText } = render(
      <PasswordConfirmStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
    );
  });

  //accordion expands when clicked on
  //accordion contains pii
});
