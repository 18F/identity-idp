import type { SinonStub } from 'sinon';
import userEvent from '@testing-library/user-event';
import { screen, waitFor } from '@testing-library/dom';
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

    it('submits the form', async () => {
      const button = screen.getByRole('button', { name: 'Submit' });
      const form = document.querySelector('form')!;

      sandbox.stub(form, 'submit');

      await userEvent.click(button);
      await waitFor(() => expect((form.submit as SinonStub).called).to.be.true());
    });

    context('with form validation errors', () => {
      beforeEach(() => {
        document.body.innerHTML = `
          <form>
            <input required>
            <lg-captcha-submit-button>
              <lg-spinner-button>
                <button>Submit</button>
              </lg-spinner-button>
            </lg-captcha-submit-button>
          </form>
        `;
      });

      it('does not submit the form and reports validity', async () => {
        const button = screen.getByRole('button', { name: 'Submit' });
        const form = document.querySelector('form')!;
        const input = document.querySelector('input')!;

        let didSubmit = false;
        form.addEventListener('submit', (event) => {
          event.preventDefault();
          didSubmit = true;
        });

        let didReportInvalid = false;
        input.addEventListener('invalid', () => {
          didReportInvalid = true;
        });

        await userEvent.click(button);

        expect(didSubmit).to.be.false();
        expect(didReportInvalid).to.be.true();
      });

      it('stops or otherwise prevents the spinner button from spinning', async () => {
        const button = screen.getByRole('button', { name: 'Submit' });
        await userEvent.click(button);

        expect(document.querySelector('.spinner-button--spinner-active')).to.not.exist();
      });
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
        expect(Object.fromEntries(new FormData(form))).to.deep.equal({
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

          sandbox.stub(form, 'submit');

          await userEvent.click(button);
          await waitFor(() => expect((form.submit as SinonStub).called).to.be.true());

          expect(grecaptcha.ready).not.to.have.been.called();
        });
      });
    });
  });
});
