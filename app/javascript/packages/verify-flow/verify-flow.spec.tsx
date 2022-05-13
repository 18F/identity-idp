import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import * as analytics from '@18f/identity-analytics';
import { useSandbox } from '@18f/identity-test-helpers';
import { STEPS } from './steps';
import VerifyFlow from './verify-flow';

describe('VerifyFlow', () => {
  const sandbox = useSandbox();
  const personalKey = '0000-0000-0000-0000';

  beforeEach(() => {
    sandbox.spy(analytics, 'trackEvent');
    sandbox.stub(window, 'fetch').resolves({
      json: () => Promise.resolve({ personal_key: personalKey }),
    } as Response);
    document.body.innerHTML = `<script type="application/json" data-config>{"appName":"Example App"}</script>`;
  });

  it('advances through flow to completion', async () => {
    const onComplete = sandbox.spy();

    const { getByText, findByText, getByLabelText } = render(
      <VerifyFlow initialValues={{ personalKey }} onComplete={onComplete} basePath="/" />,
    );

    // Password confirm
    expect(document.title).to.equal('idv.titles.session.review - Example App');
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: password confirm visited');
    expect(window.location.pathname).to.equal('/password_confirm');
    await userEvent.type(getByLabelText('components.password_toggle.label'), 'password');
    await userEvent.click(getByText('forms.buttons.continue'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: password confirm submitted');

    // Personal key
    expect(document.title).to.equal('titles.idv.personal_key - Example App');
    await findByText('idv.messages.confirm');
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key visited');
    expect(window.location.pathname).to.equal('/personal_key');
    await userEvent.click(getByText('forms.buttons.continue'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key submitted');

    // Personal key confirm
    expect(document.title).to.equal('titles.idv.personal_key - Example App');
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: personal key confirm visited');
    expect(window.location.pathname).to.equal('/personal_key_confirm');
    expect(getByText('idv.messages.confirm')).to.be.ok();
    await userEvent.type(getByLabelText('forms.personal_key.confirmation_label'), personalKey);
    await userEvent.keyboard('{Enter}');

    expect(onComplete).to.have.been.called();
  });

  context('with specific enabled steps', () => {
    it('sets details according to the first enabled steps', () => {
      render(
        <VerifyFlow
          initialValues={{ personalKey }}
          onComplete={() => {}}
          enabledStepNames={[STEPS[1].name]}
          basePath="/"
        />,
      );

      expect(document.title).to.equal(`${STEPS[1].title} - Example App`);
      expect(window.location.pathname).to.equal(`/${STEPS[1].name}`);
    });
  });
});
