import userEvent from '@testing-library/user-event';
import { screen } from '@testing-library/dom';
import {
  DocumentCapturePolling,
  MAX_DOC_CAPTURE_POLL_ATTEMPTS,
  DOC_CAPTURE_POLL_INTERVAL,
} from '@18f/identity-document-capture-polling';
import { useSandbox } from '@18f/identity-test-helpers';

describe('DocumentCapturePolling', () => {
  const sandbox = useSandbox({ useFakeTimers: true });
  const trackEvent = sandbox.spy();

  let subject;

  /**
   * Returns a promise which resolves once promises have been flushed. By spec, a promise will not
   * synchronously resolve, which conflicts with and is currently not supported by fake timers.
   *
   * @see https://github.com/sinonjs/fake-timers/issues/114
   * @see https://tc39.es/ecma262/#await
   *
   * @return {Promise<void>}
   */
  // eslint-disable-next-line no-underscore-dangle, no-void
  const flushPromises = () => Promise.resolve(void process._tickCallback());

  beforeEach(() => {
    document.body.innerHTML = `
      <a href="#" class="link-sent-back-link">Back</a>
      <form class="link-sent-continue-button-form"><button>Submit</button></form>
    `;

    subject = new DocumentCapturePolling({
      statusEndpoint: '/status',
      elements: {
        backLink: /** @type {HTMLAnchorElement} */ (document.querySelector('.link-sent-back-link')),
        form: /** @type {HTMLFormElement} */ (
          document.querySelector('.link-sent-continue-button-form')
        ),
      },
      trackEvent,
    });
    subject.bind();
  });

  afterEach(() => {
    subject.bindPromptOnNavigate(false);
  });

  it('hides form', () => {
    expect(screen.getByText('Submit').closest('.display-none')).to.be.ok();
  });

  it('polls', async () => {
    sandbox
      .stub(global, 'fetch')
      .withArgs('/status')
      .resolves({ status: 202, json: () => Promise.resolve({}) });

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    expect(global.fetch).to.have.been.calledOnce();

    await flushPromises(); // Flush `fetch`
    await flushPromises(); // Flush `json`

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    expect(global.fetch).to.have.been.calledTwice();

    expect(trackEvent).to.have.been.calledOnceWith('IdV: Link sent capture doc polling started');
  });

  it('submits when done', async () => {
    sandbox.stub(subject.elements.form, 'submit');
    sandbox
      .stub(global, 'fetch')
      .withArgs('/status')
      .resolves({ status: 200, json: () => Promise.resolve({}) });
    subject.bind();

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    await flushPromises(); // Flush `fetch`
    await flushPromises(); // Flush `json`

    expect(subject.elements.form.submit).to.have.been.called();
    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling started');
    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling complete', {
      isCancelled: false,
      isThrottled: false,
    });
  });

  it('redirects if given redirect URL on success', async () => {
    sandbox.stub(subject.elements.form, 'submit');
    sandbox
      .stub(global, 'fetch')
      .withArgs('/status')
      .resolves({ status: 200, json: () => Promise.resolve({ redirect: '#redirect' }) });

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    await flushPromises(); // Flush `fetch`
    await flushPromises(); // Flush `json`

    expect(window.location.hash).to.equal('#redirect');
    expect(subject.elements.form.submit).not.to.have.been.called();
  });

  it('submits when cancelled', async () => {
    sandbox.stub(subject.elements.form, 'submit');
    sandbox
      .stub(global, 'fetch')
      .withArgs('/status')
      .resolves({ status: 410, json: () => Promise.resolve({}) });

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    await flushPromises(); // Flush `fetch`
    await flushPromises(); // Flush `json`

    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling started');
    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling complete', {
      isCancelled: true,
      isThrottled: false,
    });
    expect(subject.elements.form.submit).to.have.been.called();
  });

  it('redirects when rate limited', async () => {
    sandbox
      .stub(global, 'fetch')
      .withArgs('/status')
      .resolves({ status: 429, json: () => Promise.resolve({ redirect: '#throttled' }) });

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    await flushPromises(); // Flush `fetch`
    await flushPromises(); // Flush `json`

    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling started');
    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling complete', {
      isCancelled: false,
      isThrottled: true,
    });
    expect(window.location.hash).to.equal('#throttled');
  });

  it('polls until max, then showing form to submit', async () => {
    sandbox
      .stub(global, 'fetch')
      .withArgs('/status')
      .resolves({ status: 202, json: () => Promise.resolve({}) });

    for (let i = MAX_DOC_CAPTURE_POLL_ATTEMPTS; i; i--) {
      sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
      // eslint-disable-next-line no-await-in-loop
      await flushPromises(); // Flush `fetch`
      // eslint-disable-next-line no-await-in-loop
      await flushPromises(); // Flush `json`
    }

    expect(screen.getByText('Submit').closest('.display-none')).to.not.be.ok();
  });

  describe('prompts', () => {
    let event;
    beforeEach(() => {
      event = new window.CustomEvent('beforeunload', { cancelable: true });
    });

    it('prompts while polling', () => {
      window.dispatchEvent(event);

      expect(event.defaultPrevented).to.be.true();
    });

    it('does not prompt by navigating away via back link', async () => {
      await userEvent.click(screen.getByText('Back'), { advanceTimers: sandbox.clock.tick });
      window.dispatchEvent(event);

      expect(event.defaultPrevented).to.be.false();
    });

    it('does not prompt by navigating away via form submission', async () => {
      sandbox.stub(subject.elements.form, 'submit');
      sandbox
        .stub(global, 'fetch')
        .withArgs('/status')
        .resolves({ status: 200, json: () => Promise.resolve({}) });
      subject.bind();
      sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
      await flushPromises(); // Flush `fetch`
      await flushPromises(); // Flush `json`
      window.dispatchEvent(event);

      expect(event.defaultPrevented).to.be.false();
    });
  });
});
