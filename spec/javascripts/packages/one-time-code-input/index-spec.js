import OneTimeCodeInput from '@18f/identity-one-time-code-input';
import { waitFor, screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { expect } from 'chai';
import { useSandbox } from '@18f/identity-test-helpers';

describe('OneTimeCodeInput', () => {
  const sandbox = useSandbox();
  const labelText = 'Enter a value:';

  function initialize({ transport = 'sms', inForm = false } = {}) {
    const input = document.createElement('input');
    input.id = 'input';
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
    const label = document.createElement('label');
    label.textContent = labelText;
    label.setAttribute('for', input.id);
    document.body.appendChild(label);
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
      it('fills value', async () => {
        const otcInput = initialize({ inForm: true });

        await waitFor(() => expect(otcInput.elements.input.value).to.equal('123456'));
        expect(navigator.credentials.get).to.have.been.calledWith({
          otp: { transport: ['sms'] },
          signal: sandbox.match.instanceOf(window.AbortSignal),
        });
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

  describe('Otp Hidden input created', () => {
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

    it('is still associated by its label', () => {
      initialize();

      expect(screen.getByLabelText(labelText)).to.be.ok();
    });

    context('in form', () => {
      it('syncs received code to hidden input', async () => {
        const otcInput = initialize({ inForm: true });
        const { hiddenInput } = otcInput.elements;

        await waitFor(() => hiddenInput.value === '123456');
      });
    });
  });

  context('in form', () => {
    it('syncs text to hidden input', async () => {
      const otcInput = initialize({ inForm: true });
      const { input, hiddenInput } = otcInput.elements;
      await userEvent.type(input, '134567');

      expect(hiddenInput.value).to.eq('134567');
    });
  });
});
