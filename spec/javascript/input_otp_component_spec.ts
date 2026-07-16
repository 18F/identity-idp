import sinon from 'sinon';
import { waitFor } from '@testing-library/dom';
import { useDefineProperty } from '@18f/identity-test-helpers';
import AdsInputOtpElement, {
  mergeInputOtpPaste,
  normalizeInputOtpValue,
} from '../../app/components/input_otp_component';

describe('InputOtpComponent', () => {
  const defineProperty = useDefineProperty();

  const createElement = ({
    value = '',
    optionalPrefix = '',
    type = 'text',
    transport,
  }: {
    value?: string;
    optionalPrefix?: string;
    type?: 'text' | 'password';
    transport?: string;
  } = {}) => {
    const form = document.createElement('form');
    const element = document.createElement('lg-ads-input-otp');
    element.dataset.length = '6';
    element.dataset.numeric = 'true';
    element.dataset.optionalPrefix = optionalPrefix;
    if (transport) {
      element.dataset.transport = transport;
    }
    element.innerHTML = `
      <label for="code">One-time code</label>
      <input
        id="code"
        name="verification[code]"
        type="${type}"
        value="${value}"
        pattern="(?:#)?[0-9]{6}"
        data-ads-input-otp-input
      />
      ${Array.from({ length: 6 }, () => '<span data-ads-input-otp-slot></span>').join('')}
    `;
    form.appendChild(element);
    document.body.appendChild(form);

    return {
      element,
      form,
      input: element.querySelector<HTMLInputElement>('input')!,
      slots: Array.from(element.querySelectorAll<HTMLElement>('[data-ads-input-otp-slot]')),
    };
  };

  afterEach(() => {
    document.body.replaceChildren();
  });

  it('enhances only after both the native input and slots are available', () => {
    const element = document.createElement('lg-ads-input-otp');
    element.dataset.length = '6';
    element.innerHTML = '<input data-ads-input-otp-input />';

    document.body.appendChild(element);

    expect(element.hasAttribute('data-enhanced')).to.be.false();
  });

  it('normalizes pasted values while preserving a valid optional prefix and selection', () => {
    expect(
      normalizeInputOtpValue('#12a 34-567', {
        length: 6,
        numeric: true,
        optionalPrefix: '#',
      }),
    ).to.equal('#123456');
    expect(
      mergeInputOtpPaste('123456', '99', { start: 2, end: 4 }, { length: 6, numeric: true }),
    ).to.equal('129956');
  });

  it('merges paste at the selection and synchronizes the visible slots', () => {
    const { input, slots } = createElement({ value: '123456' });
    input.setSelectionRange(2, 4);
    const event = new Event('paste', { bubbles: true, cancelable: true }) as ClipboardEvent;
    Object.defineProperty(event, 'clipboardData', {
      value: { getData: () => '99' },
    });

    input.dispatchEvent(event);

    expect(event.defaultPrevented).to.be.true();
    expect(input.value).to.equal('129956');
    expect(input.selectionStart).to.equal(4);
    expect(slots.map(({ textContent }) => textContent).join('')).to.equal('129956');
  });

  it('maps the caret through characters removed during normalization', () => {
    const { input, slots } = createElement();
    input.focus();
    input.value = '1-2';
    input.setSelectionRange(3, 3);

    input.dispatchEvent(new Event('input', { bubbles: true }));

    expect(input.value).to.equal('12');
    expect(input.selectionStart).to.equal(2);
    expect(slots[2].classList.contains('ads-input-otp__slot--active')).to.be.true();
  });

  it('masks password values in the presentation without changing the submitted value', () => {
    const { input, slots } = createElement({ value: '123456', type: 'password' });

    expect(input.name).to.equal('verification[code]');
    expect(input.value).to.equal('123456');
    expect(slots.map(({ textContent }) => textContent).join('')).to.equal('••••••');
  });

  it('moves the visual focus and caret with the native input selection', () => {
    const { input, slots } = createElement({ value: '12' });

    input.focus();
    input.setSelectionRange(2, 2);
    input.dispatchEvent(new Event('select'));

    expect(slots[2].classList.contains('ads-input-otp__slot--active')).to.be.true();
    expect(slots[2].classList.contains('ads-input-otp__slot--caret')).to.be.true();
  });

  it('does not show a simulated caret for readonly input', () => {
    const { input, slots } = createElement({ value: '12' });
    input.readOnly = true;
    input.focus();
    input.setSelectionRange(2, 2);
    input.dispatchEvent(new Event('select'));

    expect(slots[2].classList.contains('ads-input-otp__slot--active')).to.be.true();
    expect(slots[2].classList.contains('ads-input-otp__slot--caret')).to.be.false();
  });

  it('cleans up listeners and rebinds once when reconnected', () => {
    const { element, form, input } = createElement();
    const sync = sinon.spy(element, 'sync');

    element.remove();
    expect(element.hasAttribute('data-enhanced')).to.be.false();
    form.appendChild(element);
    sync.resetHistory();
    input.dispatchEvent(new Event('input', { bubbles: true }));

    expect(element.dataset.enhanced).to.equal('true');
    expect(sync).to.have.been.calledOnce();
  });

  it('fills the input from WebOTP and uses the configured transport', async () => {
    const getCredential = sinon.stub().resolves({ code: '123456' });
    defineProperty(AdsInputOtpElement, 'isWebOTPSupported', { value: true });
    defineProperty(navigator, 'credentials', {
      configurable: true,
      value: { get: getCredential },
    });

    const { input } = createElement({ transport: 'sms' });

    await waitFor(() => expect(input.value).to.equal('123456'));
    expect(getCredential).to.have.been.calledWith({
      otp: { transport: ['sms'] },
      signal: sinon.match.instanceOf(window.AbortSignal),
    });
  });

  it('does not let a delayed WebOTP response overwrite manual input', async () => {
    let resolveCredential!: (credential: { code: string }) => void;
    const getCredential = sinon.stub().returns(
      new Promise<{ code: string }>((resolve) => {
        resolveCredential = resolve;
      }),
    );
    defineProperty(AdsInputOtpElement, 'isWebOTPSupported', { value: true });
    defineProperty(navigator, 'credentials', {
      configurable: true,
      value: { get: getCredential },
    });
    const { input } = createElement({ transport: 'sms' });
    const signal = getCredential.firstCall.args[0].signal as AbortSignal;

    input.value = '654321';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    resolveCredential({ code: '123456' });
    await Promise.resolve();

    expect(signal.aborted).to.be.true();
    expect(input.value).to.equal('654321');
  });

  it('aborts a pending WebOTP request when disconnected', () => {
    const getCredential = sinon.stub().returns(new Promise(() => {}));
    defineProperty(AdsInputOtpElement, 'isWebOTPSupported', { value: true });
    defineProperty(navigator, 'credentials', {
      configurable: true,
      value: { get: getCredential },
    });
    const { element } = createElement({ transport: 'sms' });
    const signal = getCredential.firstCall.args[0].signal as AbortSignal;

    element.remove();

    expect(signal.aborted).to.be.true();
  });

  it('ignores WebOTP for an input replaced after the request starts', async () => {
    let resolveCredential!: (credential: { code: string }) => void;
    const getCredential = sinon.stub().returns(
      new Promise<{ code: string }>((resolve) => {
        resolveCredential = resolve;
      }),
    );
    defineProperty(AdsInputOtpElement, 'isWebOTPSupported', { value: true });
    defineProperty(navigator, 'credentials', {
      configurable: true,
      value: { get: getCredential },
    });
    const { element, input } = createElement({ transport: 'sms' });
    const replacement = input.cloneNode() as HTMLInputElement;
    replacement.value = '654321';
    input.replaceWith(replacement);

    resolveCredential({ code: '123456' });
    await Promise.resolve();

    expect(element.querySelector('input')).to.equal(replacement);
    expect(replacement.value).to.equal('654321');
  });
});
