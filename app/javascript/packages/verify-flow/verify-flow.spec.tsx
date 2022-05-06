import sinon from 'sinon';
import { render } from '@testing-library/react';
import * as analytics from '@18f/identity-analytics';
import userEvent from '@testing-library/user-event';
import VerifyFlow from './verify-flow';

describe('VerifyFlow', () => {
  const sandbox = sinon.createSandbox();
  const personalKey = '0000-0000-0000-0000';

  beforeEach(() => {
    sandbox.spy(analytics, 'trackEvent');
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('advances through flow to completion', async () => {
    const onComplete = sinon.spy();

    const { getByText, getByLabelText } = render(
      <VerifyFlow appName="Example App" initialValues={{ personalKey }} onComplete={onComplete} />,
    );

    // Personal key
    expect(getByText('idv.messages.confirm')).to.be.ok();
    await userEvent.click(getByText('forms.buttons.continue'));

    // Personal key confirm
    expect(getByText('idv.messages.confirm')).to.be.ok();
    await userEvent.type(getByLabelText('forms.personal_key.confirmation_label'), personalKey);
    await userEvent.keyboard('{Enter}');

    expect(onComplete).to.have.been.called();
  });

  it('calls trackEvents for personal key steps', async () => {
    const { getByLabelText, getByText, getAllByText } = render(
      <VerifyFlow appName="Example App" initialValues={{ personalKey }} onComplete={() => {}} />,
    );
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key visited');

    await userEvent.click(getByText('forms.buttons.continue'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key confirm visited');
    await userEvent.type(getByLabelText('forms.personal_key.confirmation_label'), personalKey);
    await userEvent.click(getAllByText('forms.buttons.continue')[1]);

    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key submitted');
  });
});
