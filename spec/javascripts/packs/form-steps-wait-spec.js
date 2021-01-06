import { fireEvent, findByRole } from '@testing-library/dom';
import { useSandbox } from '../support/sinon';
import useDefineProperty from '../support/define-property';
import { FormStepsWait } from '../../../app/javascript/packs/form-steps-wait';

describe('FormStepsWait', () => {
  const sandbox = useSandbox({ useFakeTimers: true });
  const defineProperty = useDefineProperty();

  function createForm({ action, method, options }) {
    document.body.innerHTML = `
      <form action="${action}" method="${method}" data-form-steps-wait="">
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
      .resolves({ ok: true });

    const didNativeSubmit = fireEvent.submit(form);

    expect(didNativeSubmit).to.be.false();
    mock.verify();
  });

  describe('failure', () => {
    const action = new URL('/', window.location).toString();
    const method = 'post';

    beforeEach(() => {
      sandbox
        .stub(window, 'fetch')
        .withArgs(action, sandbox.match({ method }))
        .resolves({ ok: false, status: 500 });
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

  it('navigates on redirected response', (done) => {
    const action = new URL('/', window.location).toString();
    const redirect = new URL('/next', window.location).toString();
    const method = 'post';
    const form = createForm({ action, method });
    new FormStepsWait(form).bind();
    sandbox
      .stub(window, 'fetch')
      .withArgs(action, sandbox.match({ method }))
      .resolves({ ok: true, redirected: true, url: redirect });
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
        ok: true,
        redirected: true,
        url: new URL(waitStepPath, window.location).toString(),
      })
      .withArgs(waitStepPath, sandbox.match({ method: 'HEAD' }))
      .resolves({ ok: true, redirected: true, url: redirect });

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
