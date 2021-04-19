import OneTimeCodeInput from '@18f/identity-one-time-code-input';
import { waitFor } from '@testing-library/dom';
import { useSandbox } from '../../support/sinon';

describe('OneTimeCodeInput', () => {
  const sandbox = useSandbox();

  function initialize({ transport = 'sms', inForm = false } = {}) {
    const input = document.createElement('input');
    if (transport) {
      input.dataset.transport = transport;
    }
    if (inForm) {
      const form = document.createElement('form');
      form.appendChild(input);
      document.body.appendChild(form);
    } else {
      document.body.appendChild(input);
    }
    const otcInput = new OneTimeCodeInput(document.body.querySelector('input'));
    otcInput.bind();
    return otcInput;
  }

  context('otp credential supported', () => {
    let originalIsWebOTPSupported;
    let originalCredentials;
    const onSubmit = sandbox.stub().callsFake((event) => event.preventDefault());

    beforeEach(() => {
      originalIsWebOTPSupported = OneTimeCodeInput.isWebOTPSupported;
      OneTimeCodeInput.isWebOTPSupported = true;
      originalCredentials = navigator.credentials;
      navigator.credentials = { get: sandbox.stub().resolves({ code: '123456' }) };
      window.addEventListener('submit', onSubmit);
    });

    afterEach(() => {
      OneTimeCodeInput.isWebOTPSupported = originalIsWebOTPSupported;
      navigator.credentials = originalCredentials;
      window.removeEventListener('submit', onSubmit);
    });

    context('in form', () => {
      it('fills value and submits form', async () => {
        const otcInput = initialize({ inForm: true });

        await waitFor(() => expect(otcInput.elements.input.value).to.equal('123456'));
        expect(navigator.credentials.get).to.have.been.calledWith({
          otp: { transport: ['sms'] },
          signal: sandbox.match.instanceOf(window.AbortSignal),
        });
        expect(onSubmit).to.have.been.calledOnce();
      });

      it('cancels credential receiver on submit', (done) => {
        navigator.credentials.get = sandbox.stub().callsFake(() => new Promise(() => {}));
        const otcInput = initialize({ inForm: true });
        sandbox.stub(window.AbortController.prototype, 'abort').callsFake(done);

        otcInput.elements.form.dispatchEvent(new window.CustomEvent('submit'));
      });
    });

    context('not in form', () => {
      it('fills value', async () => {
        const otcInput = initialize();

        await waitFor(() => expect(otcInput.elements.input.value).to.equal('123456'));
        expect(navigator.credentials.get).to.have.been.calledWith({
          otp: { transport: ['sms'] },
          signal: sandbox.match.instanceOf(window.AbortSignal),
        });
        expect(onSubmit).not.to.have.been.called();
      });
    });

    context('transport unset', () => {
      it('is noop', () => {
        initialize({ transport: null });

        expect(navigator.credentials.get).not.to.have.been.called();
      });
    });
  });

  context('otp credential not supported', () => {
    let originalIsWebOTPSupported;
    let originalCredentials;

    beforeEach(() => {
      originalIsWebOTPSupported = OneTimeCodeInput.isWebOTPSupported;
      OneTimeCodeInput.isWebOTPSupported = false;
      originalCredentials = navigator.credentials;
      navigator.credentials = { get: sandbox.stub() };
    });

    afterEach(() => {
      OneTimeCodeInput.isWebOTPSupported = originalIsWebOTPSupported;
      navigator.credentials = originalCredentials;
    });

    it('is noop', () => {
      initialize();

      expect(navigator.credentials.get).not.to.have.been.called();
    });
  });
});
