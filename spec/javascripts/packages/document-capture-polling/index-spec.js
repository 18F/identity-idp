import { screen } from '@testing-library/dom';
import {
  DocumentCapturePolling,
  MAX_DOC_CAPTURE_POLL_ATTEMPTS,
  DOC_CAPTURE_POLL_INTERVAL,
  POLL_ENDPOINT,
} from '@18f/identity-document-capture-polling';
import { useSandbox } from '../../support/sinon';

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
      <p id="doc_capture_continue_instructions">Instructions</p>
      <form class="doc_capture_continue_button_form"><button>Submit</button></form>
    `;

    subject = new DocumentCapturePolling({
      elements: {
        form: /** @type {HTMLFormElement} */ (document.querySelector(
          '.doc_capture_continue_button_form',
        )),
        instructions: /** @type {HTMLParagraphElement} */ (document.querySelector(
          '#doc_capture_continue_instructions',
        )),
      },
      trackEvent,
    });
    subject.bind();
  });

  it('hides form and instructions', () => {
    expect(screen.getByText('Instructions').closest('.display-none')).to.be.ok();
    expect(screen.getByText('Submit').closest('.display-none')).to.be.ok();
  });

  it('polls', async () => {
    sandbox.stub(window, 'fetch').withArgs(POLL_ENDPOINT).resolves({ status: 202 });

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    expect(window.fetch).to.have.been.calledOnce();

    await flushPromises();

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    expect(window.fetch).to.have.been.calledTwice();

    expect(trackEvent).to.have.been.calledOnceWith('IdV: Link sent capture doc polling started');
  });

  it('submits when done', async () => {
    sandbox.stub(subject.elements.form, 'submit');
    sandbox.stub(window, 'fetch').withArgs(POLL_ENDPOINT).resolves({ status: 200 });
    subject.bind();

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    await flushPromises();

    expect(subject.elements.form.submit).to.have.been.called();
    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling started');
    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling complete', {
      isCancelled: false,
    });
  });

  it('submits when cancelled', async () => {
    sandbox.stub(subject.elements.form, 'submit');
    sandbox.stub(window, 'fetch').withArgs(POLL_ENDPOINT).resolves({ status: 410 });

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    await flushPromises();

    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling started');
    expect(trackEvent).to.have.been.calledWith('IdV: Link sent capture doc polling complete', {
      isCancelled: true,
    });
    expect(subject.elements.form.submit).to.have.been.called();
  });

  it('polls until max, then showing instructions to submit', async () => {
    sandbox.stub(window, 'fetch').withArgs(POLL_ENDPOINT).resolves({ status: 202 });

    for (let i = MAX_DOC_CAPTURE_POLL_ATTEMPTS; i; i--) {
      sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
    }

    expect(screen.getByText('Instructions').closest('.display-none')).to.not.be.ok();
    expect(screen.getByText('Submit').closest('.display-none')).to.not.be.ok();
  });
});
