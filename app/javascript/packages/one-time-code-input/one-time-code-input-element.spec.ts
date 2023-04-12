import { getByLabelText, waitFor } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { useSandbox, useDefineProperty } from '@18f/identity-test-helpers';
import OneTimeCodeInputElement from './one-time-code-input-element';

describe('OneTimeCodeInputElementElement', () => {
  const sandbox = useSandbox();
  const defineProperty = useDefineProperty();

  function createElement({
    inForm,
    transport = 'sms' as OTPCredentialTransportType.SMS,
  }: { inForm?: boolean; transport?: OTPCredentialTransportType | null } = {}) {
    let html = `
      <lg-one-time-code-input${transport ? ` transport="${transport}"` : ''}>
        <label for="one-time-code-input-input-1">One-time code</label>
        <input name="code" id="one-time-code-input-input-1" class="one-time-code-input__input" value="123" />
      </lg-one-time-code-input>`;

    if (inForm) {
      html = `<form>${html}</form>`;
    }

    document.body.innerHTML = html;

    return document.querySelector('lg-one-time-code-input')!;
  }

  describe('mirrored input', () => {
    it('creates a hidden input which inherits characteristics of the original input', () => {
      const element = createElement();
      const input = getByLabelText<HTMLInputElement>(element, 'One-time code');
      const hiddenInput = element.querySelector<HTMLInputElement>('[name="code"]')!;

      expect(input.type).to.equal('text');
      expect(input.hasAttribute('name')).to.be.false();
      expect(hiddenInput.type).to.equal('hidden');
      expect(hiddenInput.name).to.equal('code');
      expect(hiddenInput.value).to.equal('123');
    });

    it('syncs text input to hidden input value on change', async () => {
      const element = createElement();
      const input = getByLabelText<HTMLInputElement>(element, 'One-time code');
      const hiddenInput = element.querySelector<HTMLInputElement>('[name="code"]')!;

      expect(hiddenInput.value).to.equal('123');
      await userEvent.type(input, '456');
      expect(hiddenInput.value).to.equal('123456');
    });

    it('replaces the input id with a unique id', () => {
      const [firstInput, secondInput] = [createElement(), createElement()].map((element) =>
        getByLabelText<HTMLInputElement>(element, 'One-time code'),
      );

      expect(firstInput.id).to.exist();
      expect(secondInput.id).to.exist();
      expect(firstInput.id).to.not.equal(secondInput.id);
    });
  });

  context('otp credential supported', () => {
    const onSubmit = sandbox.stub().callsFake((event) => event.preventDefault());

    beforeEach(() => {
      defineProperty(OneTimeCodeInputElement, 'isWebOTPSupported', { value: true });
      defineProperty(navigator, 'credentials', {
        configurable: true,
        value: { get: sandbox.stub().resolves({ code: '123456' }) },
      });
      window.addEventListener('submit', onSubmit);
    });

    afterEach(() => {
      window.removeEventListener('submit', onSubmit);
    });

    it('fills value', async () => {
      const element = createElement();
      const input = getByLabelText<HTMLInputElement>(element, 'One-time code');

      await waitFor(() => expect(input.value).to.equal('123456'));
      expect(navigator.credentials.get).to.have.been.calledWith({
        otp: { transport: ['sms'] },
        signal: sandbox.match.instanceOf(window.AbortSignal),
      });
    });

    context('in form', () => {
      it('cancels credential receiver on submit', (done) => {
        const element = createElement({ inForm: true });
        const input = getByLabelText<HTMLInputElement>(element, 'One-time code');
        navigator.credentials.get = sandbox.stub().callsFake(() => new Promise(() => {}));
        sandbox.stub(window.AbortController.prototype, 'abort').callsFake(done);

        input.form!.dispatchEvent(new window.CustomEvent('submit'));
      });
    });

    context('transport unset', () => {
      it('is noop', () => {
        createElement({ transport: null });

        expect(navigator.credentials.get).not.to.have.been.called();
      });
    });
  });

  context('otp credential not supported', () => {
    beforeEach(() => {
      defineProperty(OneTimeCodeInputElement, 'isWebOTPSupported', { value: false });
      defineProperty(navigator, 'credentials', {
        configurable: true,
        value: { get: sandbox.stub() },
      });
    });

    it('is noop', () => {
      createElement();

      expect(navigator.credentials.get).not.to.have.been.called();
    });
  });
});
