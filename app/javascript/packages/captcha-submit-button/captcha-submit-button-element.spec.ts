import type { SinonStub } from 'sinon';
import userEvent from '@testing-library/user-event';
import { screen, waitFor, fireEvent } from '@testing-library/dom';
import { useSandbox, useDefineProperty } from '@18f/identity-test-helpers';
import '@18f/identity-spinner-button/spinner-button-element';
import { CAPTCHA_EVENT_NAME } from './captcha-submit-button-element';

describe('CaptchaSubmitButtonElement', () => {
  const sandbox = useSandbox();

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

        expect(grecaptcha.ready).to.have.been.called();
        expect(grecaptcha.execute).to.have.been.calledWith(RECAPTCHA_SITE_KEY, {
          action: RECAPTCHA_ACTION_NAME,
        });
        expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
          recaptcha_token: RECAPTCHA_TOKEN_VALUE,
        });
      });

      context('with cancellation of challenge event', () => {
        beforeEach(() => {
          const form = document.querySelector('form')!;
          form.addEventListener(CAPTCHA_EVENT_NAME, (event) => event.preventDefault());
        });

        it('submits the form without challenge', async () => {
          const button = screen.getByRole('button', { name: 'Submit' });
          const form = document.querySelector('form')!;

          let didSubmit = false;
          form.addEventListener('submit', (event) => {
            event.preventDefault();
            didSubmit = true;
          });

          await userEvent.click(button);
          await waitFor(() => expect(didSubmit).to.be.true());

          expect(grecaptcha.ready).not.to.have.been.called();
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

          expect(grecaptcha.enterprise.ready).to.have.been.called();
          expect(grecaptcha.enterprise.execute).to.have.been.calledWith(RECAPTCHA_SITE_KEY, {
            action: RECAPTCHA_ACTION_NAME,
          });
          expect(Object.fromEntries(new window.FormData(form))).to.deep.equal({
            recaptcha_token: RECAPTCHA_TOKEN_VALUE,
          });
        });
      });
    });
  });
});
