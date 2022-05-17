import sinon from 'sinon';
import * as analytics from '@18f/identity-analytics';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { t } from '@18f/identity-i18n';
import { accordion } from 'identity-style-guide';
import PasswordConfirmStep from './password-confirm-step';

describe('PasswordConfirmStep', () => {
  before(() => {
    accordion.on();
  });

  after(() => {
    accordion.off();
  });

  const sandbox = sinon.createSandbox();
  const DEFAULT_PROPS = {
    onChange() {},
    onError() {},
    errors: [],
    toPreviousStep() {},
    registerField: () => () => {},
    unknownFieldErrors: [],
    value: {},
  };

  beforeEach(() => {
    sandbox.spy(analytics, 'trackEvent');
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('has a collapsed accordion by default', () => {
    const { getByText } = render(<PasswordConfirmStep {...DEFAULT_PROPS} />);

    const button = getByText(t('idv.messages.review.intro'));
    expect(button.getAttribute('aria-expanded')).to.eq('false');
  });

  it('expands accordion when the accordion is clicked on', async () => {
    const toPreviousStep = sinon.spy();
    const { getByText } = render(
      <PasswordConfirmStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
    );

    const button = getByText(t('idv.messages.review.intro'));
    await userEvent.click(button);
    expect(button.getAttribute('aria-expanded')).to.eq('true');
  });

  it('displays user information when the accordion is clicked on', async () => {
    const toPreviousStep = sinon.spy();
    const { getByText } = render(
      <PasswordConfirmStep {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />,
    );

    const button = getByText(t('idv.messages.review.intro'));
    await userEvent.click(button);

    expect(getByText('idv.review.full_name')).to.exist();
    expect(getByText('idv.review.mailing_address')).to.exist();
  });
});
