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

  let subject;

  /**
   * Returns a promise which resolves once promises have been flushed. By spec, a promise will
   * never synchronously resolve, which conflicts with an is currently not supported by Sinon clock.
   *
   * @see https://github.com/sinonjs/fake-timers/issues/114
   *
   * @return {Promise<void>}
   */
  const flushPromises = () => Promise.resolve();

  beforeEach(() => {
    document.body.innerHTML = `
      <p id="doc_capture_continue_instructions">Instructions</p>
      <form class="doc_capture_continue_button_form"><button>Submit</button></form>
    `;

    subject = new DocumentCapturePolling({
      form: /** @type {HTMLFormElement} */ (document.querySelector(
        '.doc_capture_continue_button_form',
      )),
      instructions: /** @type {HTMLParagraphElement} */ (document.querySelector(
        '#doc_capture_continue_instructions',
      )),
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
  });

  it('submits when done', async () => {
    sandbox.stub(subject.elements.form, 'submit');
    sandbox.stub(window, 'fetch').withArgs(POLL_ENDPOINT).resolves({ status: 200 });

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    await flushPromises();

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
