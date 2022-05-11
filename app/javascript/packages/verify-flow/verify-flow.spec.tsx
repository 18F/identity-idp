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
    sandbox.stub(window, 'fetch').resolves({
      json: () => Promise.resolve({ personal_key: personalKey }),
    } as Response);
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('advances through flow to completion', async () => {
    const onComplete = sinon.spy();

    const { getByText, findByText, getByLabelText } = render(
      <VerifyFlow appName="Example App" initialValues={{ personalKey }} onComplete={onComplete} />,
    );

    // Password confirm
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: password confirm visited');
    await userEvent.type(getByLabelText('idv.form.password'), 'password');
    await userEvent.click(getByText('forms.buttons.continue'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: password confirm submitted');

    // Personal key
    await findByText('idv.messages.confirm');
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key visited');
    await userEvent.click(getByText('forms.buttons.continue'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key submitted');

    // Personal key confirm
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key confirm visited');
    expect(getByText('idv.messages.confirm')).to.be.ok();
    await userEvent.type(getByLabelText('forms.personal_key.confirmation_label'), personalKey);
    await userEvent.keyboard('{Enter}');

    expect(onComplete).to.have.been.called();
  });
});
