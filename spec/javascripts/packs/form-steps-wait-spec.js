import { fireEvent, findByRole } from '@testing-library/dom';
import { useSandbox } from '../support/sinon';
import useDefineProperty from '../support/define-property';
import { FormStepsWait, getContentFromHTML } from '../../../app/javascript/packs/form-steps-wait';

describe('getContentFromHTML', () => {
  it('returns trimmed content if element exists', () => {
    const content = getContentFromHTML('<!doctype html><title>x </title>', 'title');

    expect(content).to.equal('x');
  });

  it('returns null if element does not exist', () => {
    const content = getContentFromHTML('<!doctype html><title>x </title>', 'div');

    expect(content).to.be.null();
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
              text: () => Promise.resolve('<!doctype html><title>x</title>'),
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
          beforeEach(() => {
            sandbox
              .stub(window, 'fetch')
              .withArgs(action, sandbox.match({ method }))
              .resolves({
                status: 200,
                url: window.location.href,
                redirected: true,
                text: () =>
                  Promise.resolve(
                    `<!doctype html>
                    <title>x</title>
                    <div class="usa-alert usa-alert--error">
                      <div class="usa-alert__body">
                        <p class="usa-alert__text">${errorMessage}</p>
                      </div>
                    </div>`,
                  ),
              });
          });

          it('shows message', async () => {
            const form = createForm({ action, method });
            new FormStepsWait(form).bind();

            fireEvent.submit(form);

            const alert = await findByRole(form, 'alert');
            expect(alert.textContent).to.equal(errorMessage);
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
              })
              .withArgs(waitStepPath)
              .resolves({
                status: 200,
                redirected: true,
                url: window.location.href,
                text: () =>
                  Promise.resolve(
                    `<!doctype html>
                    <title>x</title>
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
      .resolves({ status: 200, redirected: true, url: redirect });
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
      })
      .withArgs(waitStepPath)
      .resolves({ status: 200, redirected: true, url: redirect });

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
