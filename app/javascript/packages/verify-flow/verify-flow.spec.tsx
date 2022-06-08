import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import * as analytics from '@18f/identity-analytics';
import { useSandbox } from '@18f/identity-test-helpers';
import { STEPS } from './steps';
import VerifyFlow, { VerifyFlowProps } from './verify-flow';

describe('VerifyFlow', () => {
  const sandbox = useSandbox();
  const personalKey = '0000-0000-0000-0000';
  const DEFAULT_PROPS = {
    basePath: '/',
    initialAddressVerificationMethod: 'phone',
    onComplete: () => {},
  } as VerifyFlowProps;

  beforeEach(() => {
    sandbox.spy(analytics, 'trackEvent');
    sandbox.stub(window, 'fetch').resolves({
      json: () =>
        Promise.resolve({ personal_key: personalKey, completion_url: 'http://example.com' }),
    } as Response);
    document.body.innerHTML = `<script type="application/json" data-config>{"appName":"Example App"}</script>`;
  });

  it('advances through flow to completion', async () => {
    const onComplete = sandbox.spy();

    const { getByText, findByText, getByLabelText } = render(
      <VerifyFlow {...DEFAULT_PROPS} initialValues={{ personalKey }} onComplete={onComplete} />,
    );

    // Password confirm
    expect(document.title).to.equal('idv.titles.session.review - Example App');
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: password confirm visited');
    expect(window.location.pathname).to.equal('/password_confirm');
    await userEvent.type(getByLabelText('components.password_toggle.label'), 'password');
    await userEvent.click(getByText('forms.buttons.continue'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: password confirm submitted');

    // Personal key
    expect(sessionStorage.getItem('completedStep')).to.equal('password_confirm');
    expect(document.title).to.equal('titles.idv.personal_key - Example App');
    await findByText('idv.messages.confirm');
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key visited');
    expect(window.location.pathname).to.equal('/personal_key');
    await userEvent.click(getByText('forms.buttons.continue'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key submitted');

    // Personal key confirm
    expect(sessionStorage.getItem('completedStep')).to.equal('personal_key');
    expect(document.title).to.equal('titles.idv.personal_key - Example App');
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key confirm visited');
    expect(window.location.pathname).to.equal('/personal_key_confirm');
    expect(getByText('idv.messages.confirm')).to.be.ok();
    await userEvent.type(getByLabelText('forms.personal_key.confirmation_label'), personalKey);
    await userEvent.keyboard('{Enter}');

    expect(onComplete).to.have.been.calledWith(
      sinon.match({ completionURL: 'http://example.com' }),
    );
    expect(sessionStorage.getItem('completedStep')).to.be.null();
  });

  context('with specific enabled steps', () => {
    it('sets details according to the first enabled steps', () => {
      render(
        <VerifyFlow
          {...DEFAULT_PROPS}
          initialValues={{ personalKey }}
          enabledStepNames={[STEPS[1].name]}
        />,
      );

      expect(document.title).to.equal(`${STEPS[1].title} - Example App`);
      expect(window.location.pathname).to.equal(`/${STEPS[1].name}`);
    });
  });
});
