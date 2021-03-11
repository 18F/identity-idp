import { screen } from '@testing-library/dom';
import {
  DocumentCapturePolling,
  MAX_DOC_CAPTURE_POLL_ATTEMPTS,
  DOC_CAPTURE_POLL_INTERVAL,
  POLL_ENDPOINT,
} from '@18f/identity-document-capture-polling';
import { LOGGER_ENDPOINT } from '@18f/identity-analytics';
import { useSandbox } from '../../support/sinon';

describe('DocumentCapturePolling', () => {
  const sandbox = useSandbox({ useFakeTimers: true });

  /**
   * Returns a promise which resolves once promises have been flushed. By spec, a promise will
   * never synchronously resolve, which conflicts with an is currently not supported by Sinon clock.
   *
   * @see https://github.com/sinonjs/fake-timers/issues/114
   *
   * @return {Promise<void>}
   */
  const flushPromises = () => process._tickCallback(); // eslint-disable-line no-underscore-dangle

  beforeEach(() => {
    document.body.innerHTML = `
      <p id="doc_capture_continue_instructions">Instructions</p>
      <form class="doc_capture_continue_button_form"><button>Submit</button></form>
    `;
  });

  const getInstance = () =>
    new DocumentCapturePolling({
      form: /** @type {HTMLFormElement} */ (document.querySelector(
        '.doc_capture_continue_button_form',
      )),
      instructions: /** @type {HTMLParagraphElement} */ (document.querySelector(
        '#doc_capture_continue_instructions',
      )),
    });

  it('hides form and instructions', () => {
    getInstance().bind();
    expect(screen.getByText('Instructions').closest('.display-none')).to.be.ok();
    expect(screen.getByText('Submit').closest('.display-none')).to.be.ok();
  });

  it('polls', async () => {
    sandbox.stub(window, 'fetch').withArgs(POLL_ENDPOINT).resolves({ status: 202 });
    getInstance().bind();

    await flushPromises();
    expect(window.fetch).to.have.been.calledOnceWith(LOGGER_ENDPOINT);

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    expect(window.fetch).to.have.been.calledTwice();
    expect(window.fetch.getCall(1).args[0]).to.equal(POLL_ENDPOINT);

    await flushPromises();

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    expect(window.fetch).to.have.been.calledThrice();
    expect(window.fetch.getCall(2).args[0]).to.equal(POLL_ENDPOINT);
  });

  it('submits when done', async () => {
    const instance = getInstance();
    sandbox.stub(instance.elements.form, 'submit');
    sandbox.stub(window, 'fetch');
    window.fetch.withArgs(POLL_ENDPOINT).resolves({ status: 200 });
    window.fetch.withArgs(LOGGER_ENDPOINT).resolves({ status: 200 });
    instance.bind();

    sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
    await flushPromises();

    expect(instance.elements.form.submit).to.have.been.called();
  });

  it('polls until max, then showing instructions to submit', async () => {
    sandbox.stub(window, 'fetch').withArgs(POLL_ENDPOINT).resolves({ status: 202 });
    getInstance().bind();

    for (let i = MAX_DOC_CAPTURE_POLL_ATTEMPTS; i; i--) {
      sandbox.clock.tick(DOC_CAPTURE_POLL_INTERVAL);
      // eslint-disable-next-line no-await-in-loop
      await flushPromises();
    }

    expect(screen.getByText('Instructions').closest('.display-none')).to.not.be.ok();
    expect(screen.getByText('Submit').closest('.display-none')).to.not.be.ok();
  });
});
