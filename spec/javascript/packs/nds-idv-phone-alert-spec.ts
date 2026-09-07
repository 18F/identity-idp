import { initialize } from '../../../app/javascript/packs/nds-idv-phone-alert';

describe('nds-idv-phone-alert', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  const buildPage = (failedPhoneNumbers: string[] = ['+12025551234']) => {
    document.body.innerHTML = `
      <div
        id="phone-already-submitted-alert"
        data-failed-phone-numbers='${JSON.stringify(failedPhoneNumbers)}'
        hidden
      ></div>
      <div class="usa-phone-input-group" data-nds-phone>
        <input type="radio" name="country" value="US" data-nds-phone-country checked />
        <input type="radio" name="country" value="GB" data-nds-phone-country />
        <input type="tel" class="usa-phone-input__input" />
      </div>
    `;
    return {
      alert: document.querySelector<HTMLElement>('#phone-already-submitted-alert')!,
      phone: document.querySelector<HTMLInputElement>('.usa-phone-input__input')!,
      gb: document.querySelector<HTMLInputElement>('input[value=GB]')!,
    };
  };

  const type = (phone: HTMLInputElement, value: string) => {
    phone.value = value;
    phone.dispatchEvent(new Event('input', { bubbles: true }));
  };

  it('stays hidden until a failed number is entered', () => {
    const { alert, phone } = buildPage();

    initialize();
    expect(alert.hidden).to.be.true();

    type(phone, '(202) 555-9999');
    expect(alert.hidden).to.be.true();
  });

  it('shows the alert when the typed number matches a failed number', () => {
    const { alert, phone } = buildPage();

    initialize();
    type(phone, '(202) 555-1234');

    expect(alert.hidden).to.be.false();
  });

  it('re-hides the alert when the number changes away from a failed number', () => {
    const { alert, phone } = buildPage();

    initialize();
    type(phone, '2025551234');
    type(phone, '2025551235');

    expect(alert.hidden).to.be.true();
  });

  it('accounts for the selected country when matching', () => {
    const { alert, phone, gb } = buildPage(['+442071234567']);

    initialize();
    type(phone, '020 7123 4567');
    expect(alert.hidden).to.be.true();

    gb.checked = true;
    gb.dispatchEvent(new Event('change', { bubbles: true }));
    expect(alert.hidden).to.be.false();
  });

  it('is a no-op without the alert or phone group', () => {
    document.body.innerHTML = '<div class="usa-phone-input-group" data-nds-phone></div>';

    expect(() => initialize()).not.to.throw();
  });
});
