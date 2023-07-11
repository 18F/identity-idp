import { fireEvent, findByRole } from '@testing-library/dom';
import { useSandbox } from '@18f/identity-test-helpers';
import {
  FormStepsWait,
  getDOMFromHTML,
  isPollingPage,
  getPageErrorMessage,
} from '../../../app/javascript/packs/form-steps-wait';

const POLL_PAGE_MARKUP = '<meta content="1" http-equiv="refresh">Example';
const NON_POLL_PAGE_MARKUP = 'Example';

describe('getDOMFromHTML', () => {
  it('returns document of given markup', () => {
    const dom = getDOMFromHTML(NON_POLL_PAGE_MARKUP);

    expect(dom.body.textContent).to.equal('Example');
  });
});

describe('isPollingPage', () => {
  it('returns true if polling markup exists in page', () => {
    const dom = getDOMFromHTML(POLL_PAGE_MARKUP);
    const result = isPollingPage(dom);

    expect(result).to.equal(true);
  });

  it('returns false if polling markup does not exist in page', () => {
    const dom = getDOMFromHTML(NON_POLL_PAGE_MARKUP);
    const result = isPollingPage(dom);

    expect(result).to.equal(false);
  });
});

describe('getPageErrorMessage', () => {
  it('returns error message if polling markup exists in page', () => {
    const errorMessage = 'An error occurred!';
    const dom = getDOMFromHTML(
      `${NON_POLL_PAGE_MARKUP}
      <div class="usa-alert usa-alert--error">
        <div class="usa-alert__body">
          <p class="usa-alert__text">${errorMessage}</p>
        </div>
      </div>`,
    );
    const result = getPageErrorMessage(dom);

    expect(result).to.equal(errorMessage);
  });

  it('returns falsey if markup does not include alert', () => {
    const dom = getDOMFromHTML(NON_POLL_PAGE_MARKUP);
    const result = getPageErrorMessage(dom);

    expect(result).to.not.be.ok();
  });

  it('returns falsey if markup contains non-error alert', () => {
    const dom = getDOMFromHTML(
      `${NON_POLL_PAGE_MARKUP}
      <div class="usa-alert usa-alert--success">
        <div class="usa-alert__body">
          <p class="usa-alert__text">Good news, everyone!</p>
        </div>
      </div>`,
    );
    const result = getPageErrorMessage(dom);

    expect(result).to.not.be.ok();
  });
});

describe('FormStepsWait', () => {
  const sandbox = useSandbox({ useFakeTimers: true });

  function createForm({ action, method, options, navigate = sandbox.stub() }) {
    document.body.innerHTML = `
      <form
        action="${action}"
        method="${method}"
        data-form-steps-wait=""
        data-alert-target="#alert-target"
      >
        <div id="alert-target"></div>
        <input type="text" id="text-name" aria-label="foo">
        <input type="hidden" name="foo" value="bar">
      </form>
    `;

    const form = document.body.firstElementChild;
    Object.assign(form.dataset, options);
    new FormStepsWait(form, { navigate }).bind();
    return form;
  }

  it('submits form via fetch', () => {
    const action = new URL('/', window.location).toString();
    const method = 'post';
    const form = createForm({ action, method });
    const mock = sandbox
      .mock(global)
      .expects('fetch')
      .once()
      .withArgs(
        action,
        sandbox.match({
          method,
          body: sandbox.match((formData) => /** @type {FormData} */ (formData).has('foo')),
        }),
      )
      .resolves({ status: 200 });

    const didNativeSubmit = fireEvent.submit(form);

    expect(didNativeSubmit).to.be.false();
    mock.verify();
  });

  describe('failure', () => {
    const action = new URL('/', window.location).toString();
    const method = 'post';

    context('server error', () => {
      beforeEach(() => {
        sandbox
          .stub(global, 'fetch')
          .withArgs(action, sandbox.match({ method }))
          .resolves({ ok: false, status: 500, url: 'http://example.com' });
      });

      it('stops spinner', (done) => {
        const form = createForm({ action, method });
        fireEvent.submit(form);
        form.addEventListener('spinner.stop', () => done());
      });

      context('error message configured', () => {
        const errorMessage = 'An error occurred!';

        /** @type {HTMLFormElement} */
        let form;
        beforeEach(() => {
          form = createForm({ action, method, options: { errorMessage } });
        });

        it('shows message', async () => {
          fireEvent.submit(form);
          const alert = await findByRole(form, 'alert');
          expect(alert.textContent).to.equal(errorMessage);
        });
      });
    });

    context('handled error', () => {
      context('alert not in response', () => {
        const redirect = window.location.href;
        beforeEach(() => {
          sandbox
            .stub(global, 'fetch')
            .withArgs(action, sandbox.match({ method }))
            .resolves({
              status: 200,
              url: redirect,
              redirected: true,
              text: () => Promise.resolve(NON_POLL_PAGE_MARKUP),
            });
        });

        it('redirects', async () => {
          const navigate = sandbox.stub();
          const form = createForm({ action, method, navigate });

          fireEvent.submit(form);

          await expect(navigate).to.eventually.be.calledWith(redirect);
        });
      });

      context('alert in response', () => {
        const errorMessage = 'An error occurred!';

        context('synchronous resolution', () => {
          const createResponse = (suffix = '') => ({
            status: 200,
            url: window.location.href,
            redirected: true,
            text: () =>
              Promise.resolve(
                `${NON_POLL_PAGE_MARKUP}
                <div class="usa-alert usa-alert--error">
                  <div class="usa-alert__body">
                    <p class="usa-alert__text">${errorMessage}${suffix}</p>
                  </div>
                </div>`,
              ),
          });

          beforeEach(() => {
            sandbox
              .stub(global, 'fetch')
              .withArgs(action, sandbox.match({ method }))
              .onFirstCall()
              .resolves(createResponse())
              .onSecondCall()
              .resolves(createResponse(' Again!'));
          });

          it('shows message', async () => {
            const form = createForm({ action, method });

            fireEvent.submit(form);

            const alert = await findByRole(form, 'alert');
            expect(alert.textContent).to.equal(errorMessage);
          });

          it('replaces previous message', async () => {
            const form = createForm({ action, method });

            fireEvent.submit(form);

            let alert = await findByRole(form, 'alert');
            expect(alert.textContent).to.equal(errorMessage);

            fireEvent.submit(form);

            alert = await findByRole(form, 'alert');
            expect(alert.textContent).to.equal(`${errorMessage} Again!`);
          });
        });

        context('asynchronous resolution', () => {
          const waitStepPath = '/wait';

          beforeEach(() => {
            sandbox
              .stub(global, 'fetch')
              .withArgs(action, sandbox.match({ method }))
              .resolves({
                status: 200,
                redirected: true,
                url: new URL(waitStepPath, window.location).toString(),
                text: () => Promise.resolve(POLL_PAGE_MARKUP),
              })
              .withArgs(waitStepPath)
              .resolves({
                status: 200,
                redirected: true,
                url: window.location.href,
                text: () =>
                  Promise.resolve(
                    `${NON_POLL_PAGE_MARKUP}
                    <div class="usa-alert usa-alert--error">
                      <div class="usa-alert__body">
                        <p class="usa-alert__text">${errorMessage}</p>
                      </div>
                    </div>`,
                  ),
              });
          });

          it('shows message', async () => {
            const form = createForm({
              action,
              method,
              options: { waitStepPath, pollIntervalMs: 0 },
            });
            sandbox.clock.restore(); // Disable fake clock since we'll poll instantly

            fireEvent.submit(form);

            const alert = await findByRole(form, 'alert');
            expect(alert.textContent).to.equal(errorMessage);
          });
        });
      });
    });
  });

  it('navigates on redirected response', async () => {
    const action = new URL('/', window.location).toString();
    const redirect = new URL('/next', window.location).toString();
    const method = 'post';
    const navigate = sandbox.stub();
    const form = createForm({ action, method, navigate });
    sandbox
      .stub(global, 'fetch')
      .withArgs(action, sandbox.match({ method }))
      .resolves({
        status: 200,
        redirected: true,
        url: redirect,
        text: () =>
          Promise.resolve(
            `${NON_POLL_PAGE_MARKUP}
            <div class="usa-alert usa-alert--error">
              <div class="usa-alert__body">
                <p class="usa-alert__text">Error on redirected page is fine.</p>
              </div>
            </div>`,
          ),
      });

    fireEvent.submit(form);
    await expect(navigate).to.eventually.be.calledWith(redirect);
  });

  it('polls for completion', async () => {
    const action = new URL('/', window.location).toString();
    const pollIntervalMs = 1000;
    const waitStepPath = '/wait';
    const redirect = new URL('/next', window.location).toString();
    const method = 'post';
    const navigate = sandbox.stub();
    const form = createForm({
      action,
      method,
      options: { waitStepPath, pollIntervalMs },
      navigate,
    });
    sandbox
      .stub(global, 'fetch')
      .withArgs(action, sandbox.match({ method }))
      .resolves({
        status: 200,
        redirected: true,
        url: new URL(waitStepPath, window.location).toString(),
        text: () => Promise.resolve(POLL_PAGE_MARKUP),
      })
      .withArgs(waitStepPath)
      .resolves({
        status: 200,
        redirected: true,
        url: redirect,
        text: () => Promise.resolve(NON_POLL_PAGE_MARKUP),
      });

    fireEvent.submit(form);
    sandbox.stub(global, 'setTimeout').callsFake((callback, timeout) => {
      expect(timeout).to.equal(pollIntervalMs);
      callback();
    });
    await expect(navigate).to.eventually.be.calledWith(redirect);
  });
});
