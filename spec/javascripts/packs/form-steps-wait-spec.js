import { fireEvent, findByRole } from '@testing-library/dom';
import { useDefineProperty } from '@18f/identity-test-helpers';
import { useSandbox } from '../support/sinon';
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
  const defineProperty = useDefineProperty();

  function createForm({ action, method, options }) {
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
    return form;
  }

  it('submits form via fetch', () => {
    const action = new URL('/', window.location).toString();
    const method = 'post';
    const form = createForm({ action, method });
    new FormStepsWait(form).bind();
    const mock = sandbox
      .mock(window)
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
          .stub(window, 'fetch')
          .withArgs(action, sandbox.match({ method }))
          .resolves({ ok: false, status: 500, url: 'http://example.com' });
      });

      it('stops spinner', (done) => {
        const form = createForm({ action, method });
        new FormStepsWait(form).bind();
        fireEvent.submit(form);
        form.addEventListener('spinner.stop', () => done());
      });

      context('error message configured', () => {
        const errorMessage = 'An error occurred!';

        /** @type {HTMLFormElement} */
        let form;
        beforeEach(() => {
          form = createForm({ action, method });
          form.setAttribute('data-error-message', errorMessage);
          new FormStepsWait(form).bind();
        });

        it('shows message', async () => {
          fireEvent.submit(form);
          const alert = await findByRole(form, 'alert');
          expect(alert.textContent).to.equal(errorMessage);
        });
      });
    });

    context('invalid input', () => {
      let form;
      let input;
      beforeEach(() => {
        form = createForm({ action, method });
        input = form.querySelector('#text-name');
        input.setAttribute('required', '');
      });
      it('stops spinner', (done) => {
        new FormStepsWait(form).bind();
        form.addEventListener('spinner.stop', () => done());

        fireEvent.invalid(input);
      });
    });

    context('handled error', () => {
      context('alert not in response', () => {
        const redirect = window.location.href;
        beforeEach(() => {
          sandbox
            .stub(window, 'fetch')
            .withArgs(action, sandbox.match({ method }))
            .resolves({
              status: 200,
              url: redirect,
              redirected: true,
              text: () => Promise.resolve(NON_POLL_PAGE_MARKUP),
            });
        });

        it('redirects', (done) => {
          const form = createForm({ action, method });
          new FormStepsWait(form).bind();

          fireEvent.submit(form);

          const { pathname } = window.location;

          defineProperty(window, 'location', {
            value: {
              get pathname() {
                return pathname;
              },
              set href(url) {
                expect(url).to.equal(redirect);
                done();
              },
            },
          });
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
              .stub(window, 'fetch')
              .withArgs(action, sandbox.match({ method }))
              .onFirstCall()
              .resolves(createResponse())
              .onSecondCall()
              .resolves(createResponse(' Again!'));
          });

          it('shows message', async () => {
            const form = createForm({ action, method });
            new FormStepsWait(form).bind();

            fireEvent.submit(form);

            const alert = await findByRole(form, 'alert');
            expect(alert.textContent).to.equal(errorMessage);
          });

          it('replaces previous message', async () => {
            const form = createForm({ action, method });
            new FormStepsWait(form).bind();

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
              .stub(window, 'fetch')
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
            sandbox.stub(global, 'setTimeout').callsArg(0);
          });

          it('shows message', async () => {
            const form = createForm({
              action,
              method,
              options: { waitStepPath, pollIntervalMs: 0 },
            });
            new FormStepsWait(form).bind();

            fireEvent.submit(form);

            const alert = await findByRole(form, 'alert');
            expect(alert.textContent).to.equal(errorMessage);
          });
        });
      });
    });
  });

  it('navigates on redirected response', (done) => {
    const action = new URL('/', window.location).toString();
    const redirect = new URL('/next', window.location).toString();
    const method = 'post';
    const form = createForm({ action, method });
    new FormStepsWait(form).bind();
    sandbox
      .stub(window, 'fetch')
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
    defineProperty(window, 'location', {
      value: {
        set href(url) {
          expect(url).to.equal(redirect);
          done();
        },
      },
    });

    fireEvent.submit(form);
  });

  it('polls for completion', (done) => {
    const action = new URL('/', window.location).toString();
    const pollIntervalMs = 1000;
    const waitStepPath = '/wait';
    const redirect = new URL('/next', window.location).toString();
    const method = 'post';
    const form = createForm({ action, method, options: { waitStepPath, pollIntervalMs } });
    new FormStepsWait(form).bind();
    sandbox
      .stub(window, 'fetch')
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

    defineProperty(window, 'location', {
      value: {
        set href(url) {
          expect(url).to.equal(redirect);
          done();
        },
      },
    });

    fireEvent.submit(form);
    sandbox.stub(global, 'setTimeout').callsFake((callback, timeout) => {
      expect(timeout).to.equal(pollIntervalMs);
      callback();
    });
  });
});
