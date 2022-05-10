import sinon from 'sinon';
import * as analytics from '@18f/identity-analytics';
import { render, screen, fireEvent, createEvent } from '@testing-library/react';
import { usePropertyValue } from '@18f/identity-test-helpers';
import PasswordConfirmStep from './password-confirm-step';
import userEvent from '@testing-library/user-event';
import { t } from '@18f/identity-i18n';

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

  it('it has a collapsed accordion by default', async () => {
    const toPreviousStep = sinon.spy();
    const { getByText } = render(
      <PasswordConfirmStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
    );

    const button = getByText(t('idv.messages.review.intro'));
    expect(button.getAttribute('aria-expanded')).to.eq('false');
  });

  it('it expands accordion when clicked on', async () => {
    const toPreviousStep = sinon.spy();
    const { getByText } = render(
      <PasswordConfirmStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
    );

    const button = getByText(t('idv.messages.review.intro'));
    await userEvent.click(button);
    expect(button.getAttribute('aria-expanded')).to.eq('true');
  });
});
