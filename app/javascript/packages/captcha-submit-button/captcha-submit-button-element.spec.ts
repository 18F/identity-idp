import quibble from 'quibble';
import type { SinonStub } from 'sinon';
import baseUserEvent from '@testing-library/user-event';
import { screen, waitFor, fireEvent } from '@testing-library/dom';
import { useSandbox, useDefineProperty } from '@18f/identity-test-helpers';
import '@18f/identity-spinner-button/spinner-button-element';

describe('CaptchaSubmitButtonElement', () => {
  let FAILED_LOAD_DELAY_MS: number;
  const sandbox = useSandbox({ useFakeTimers: true });
  const { clock } = sandbox;
  const userEvent = baseUserEvent.setup({ advanceTimers: clock.tick });
  const trackError = sandbox.stub();

  before(async () => {
    quibble('@18f/identity-analytics', { trackError });
    ({ FAILED_LOAD_DELAY_MS } = await import('./captcha-submit-button-element'));
  });

  afterEach(() => {
    trackError.reset();
  });

  after(() => {
    quibble.reset();
  });

  context('without ancestor form element', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <lg-captcha-submit-button>
          <button>Submit</button>
        </lg-captcha-submit-button>
      `;
    });

    it('gracefully handles button click as noop', async () => {
      const button = screen.getByRole('button', { name: 'Submit' });

      await userEvent.click(button);
    });
  });

  context('with ancestor form element', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <form>
          <lg-captcha-submit-button>
            <button>Submit</button>
          </lg-captcha-submit-button>
        </form>
      `;
    });

    it('does not prevent default form submission', async () => {
      const button = screen.getByRole('button', { name: 'Submit' });
      const form = document.querySelector('form')!;

      let didSubmit = false;
      form.addEventListener('submit', (event) => {
        expect(event.defaultPrevented).to.equal(false);
        event.preventDefault();
        didSubmit = true;
      });

      await userEvent.click(button);
      await waitFor(() => expect(didSubmit).to.be.true());
    });

    it('unbinds form events when disconnected', () => {
      const submitButton = document.querySelector('lg-captcha-submit-button')!;
      const form = submitButton.form!;
      form.removeChild(submitButton);

      sandbox.spy(submitButton, 'shouldInvokeChallenge');
      fireEvent.submit(form);

      expect(submitButton.shouldInvokeChallenge).not.to.have.been.called();
    });

    context('with configured recaptcha', () => {
      const RECAPTCHA_TOKEN_VALUE = 'token';
      const RECAPTCHA_SITE_KEY = 'site_key';
      const RECAPTCHA_ACTION_NAME = 'action_name';
      const defineProperty = useDefineProperty();

      beforeEach(() => {
        document.body.innerHTML = `
          <form>
            <lg-captcha-submit-button
              recaptcha-site-key="${RECAPTCHA_SITE_KEY}"
              recaptcha-action="${RECAPTCHA_ACTION_NAME}"
              recaptcha-enterprise="false"
            >
              <input type="hidden" name="recaptcha_token">
              <button>Submit</button>
            </lg-captcha-submit-button>
          </form>
        `;

        defineProperty(global, 'grecaptcha', {
          configurable: true,
          value: {
            ready: sandbox.stub().callsArg(0),
            execute: sandbox.stub().resolves(RECAPTCHA_TOKEN_VALUE),
            enterprise: {
              ready: sandbox.stub().callsArg(0),
              execute: sandbox.stub().resolves(RECAPTCHA_TOKEN_VALUE),
            },
          },
        });
      });

      it('invokes recaptcha challenge and submits form', async () => {
        const button = screen.getByRole('button', { name: 'Submit' });
        const form = document.querySelector('form')!;

        sandbox.stub(form, 'submit');

        await userEvent.click(button);
        await waitFor(() => expect((form.submit as SinonStub).called).to.be.true());

        expect(grecaptcha.execute).to.have.been.calledWith(RECAPTCHA_SITE_KEY, {
          action: RECAPTCHA_ACTION_NAME,
        });
        expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
          recaptcha_token: RECAPTCHA_TOKEN_VALUE,
        });
      });

      context('with recaptcha not loaded by time of submission', () => {
        beforeEach(() => {
          delete (global as any).grecaptcha;
        });

        it('enqueues the challenge callback to be run once recaptcha loads', async () => {
          const button = screen.getByRole('button', { name: 'Submit' });
          const form = document.querySelector('form')!;
          sandbox.stub(form, 'submit');

          await userEvent.click(button);

          expect(form.submit).not.to.have.been.called();
          /* eslint-disable no-underscore-dangle */
          expect((globalThis as any).___grecaptcha_cfg).to.have.keys('fns');
          expect((globalThis as any).___grecaptcha_cfg.fns)
            .to.be.an('array')
            .with.lengthOf.greaterThan(0);
          (globalThis as any).___grecaptcha_cfg.fns.forEach((callback) => callback());
          /* eslint-enable no-underscore-dangle */

          await expect(form.submit).to.eventually.be.called();
        });
      });

      context('with only recaptcha loader script loaded by time of submission', () => {
        // The loader script will define the `grecaptcha` global and `ready` function, but it will
        // not define `execute`.
        beforeEach(() => {
          delete (global as any).grecaptcha.execute;
          delete (global as any).grecaptcha.enterprise.execute;
        });

        it('enqueues the challenge callback to be run once recaptcha loads', async () => {
          const button = screen.getByRole('button', { name: 'Submit' });
          const form = document.querySelector('form')!;
          sandbox.stub(form, 'submit');

          await userEvent.click(button);

          expect(grecaptcha.ready).to.have.been.called();

          // Simulate reCAPTCHA full script loaded
          (global as any).grecaptcha.execute = sandbox.stub().resolves(RECAPTCHA_TOKEN_VALUE);
          const callback = (grecaptcha.ready as SinonStub).getCall(0).args[0];
          callback();

          await expect(form.submit).to.eventually.be.called();
        });
      });

      context('with recaptcha enterprise', () => {
        beforeEach(() => {
          const element = document.querySelector('lg-captcha-submit-button')!;
          element.setAttribute('recaptcha-enterprise', 'true');
        });

        it('invokes recaptcha challenge and submits form', async () => {
          const button = screen.getByRole('button', { name: 'Submit' });
          const form = document.querySelector('form')!;

          sandbox.stub(form, 'submit');

          await userEvent.click(button);
          await waitFor(() => expect((form.submit as SinonStub).called).to.be.true());

          expect(grecaptcha.enterprise.execute).to.have.been.calledWith(RECAPTCHA_SITE_KEY, {
            action: RECAPTCHA_ACTION_NAME,
          });
          expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
            recaptcha_token: RECAPTCHA_TOKEN_VALUE,
          });
        });
      });

      context('when recaptcha fails to load', () => {
        beforeEach(() => {
          delete (global as any).grecaptcha;
        });

        it('submits the form if recaptcha is still not loaded after reasonable delay', async () => {
          const button = screen.getByRole('button', { name: 'Submit' });
          const form = document.querySelector('form')!;
          sandbox.stub(form, 'submit');

          await userEvent.click(button);

          expect(form.submit).not.to.have.been.called();
          clock.tick(FAILED_LOAD_DELAY_MS - 1);
          expect(form.submit).not.to.have.been.called();
          clock.tick(1);
          expect(form.submit).to.have.been.called();
        });
      });

      context('when recaptcha fails to execute', () => {
        let error: Error;

        beforeEach(() => {
          error = new Error('Invalid site key or not loaded in api.js: badkey');
          ((global as any).grecaptcha.execute as SinonStub).throws(error);
        });

        it('does not prevent default form submission', async () => {
          const button = screen.getByRole('button', { name: 'Submit' });
          const form = document.querySelector('form')!;
          sandbox.stub(form, 'submit');

          await userEvent.click(button);

          await expect(form.submit).to.eventually.be.called();
          await expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
            recaptcha_token: '',
          });
        });

        it('tracks error', async () => {
          const button = screen.getByRole('button', { name: 'Submit' });
          const form = document.querySelector('form')!;
          sandbox.stub(form, 'submit');

          await userEvent.click(button);

          await expect(trackError).to.eventually.be.calledWith(error);
        });
      });
    });
  });
});
