import { getByLabelText } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import type { SinonStub } from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import { CAPTCHA_EVENT_NAME } from '@18f/identity-captcha-submit-button/captcha-submit-button-element';

const MULTIPLE_OPTIONS_HTML = `
  <select class="phone-input__international-code" data-countries="[&quot;CA&quot;,&quot;US&quot;]" id="phone_form_international_code">
    <option data-supports-sms="true" data-supports-voice="true" data-country-code="1" data-country-name="United States" value="US">United States +1</option>
    <option data-supports-sms="true" data-supports-voice="false" data-country-code="1" data-country-name="Canada" value="CA">Canada +1</option>
    <option data-supports-sms="false" data-supports-voice="false" data-country-code="94" data-country-name="Sri Lanka" value="LK">Sri Lanka +94</option>
  </select>`;

const SINGLE_OPTION_HTML = `
  <select class="phone-input__international-code" data-countries="[&quot;US&quot;]" id="phone_form_international_code">
    <option data-supports-sms="true" data-supports-voice="true" data-country-code="1" data-country-name="United States" value="US">United States +1</option>
  </select>`;

const SINGLE_OPTION_SELECT_NON_US_HTML = `
  <select class="phone-input__international-code" data-countries="[&quot;CA&quot;]" id="phone_form_international_code">
    <option data-supports-sms="true" data-supports-voice="false" data-country-code="1" data-country-name="Canada" value="CA">Canada +1</option>
  </select>`;

describe('PhoneInput', () => {
  const sandbox = useSandbox();

  before(async () => {
    await import('intl-tel-input/build/js/utils.js');
    window.intlTelInputUtils = global.intlTelInputUtils;
    await import('./index');
  });

  function createAndConnectElement({
    isSingleOption = false,
    isNonUSSingleOption = false,
    deliveryMethods = ['sms', 'voice'],
    translatedCountryCodeNames = {},
    captchaExemptCountries = undefined,
  }: {
    isSingleOption?: boolean;
    isNonUSSingleOption?: Boolean;
    deliveryMethods?: string[];
    translatedCountryCodeNames?: Record<string, string>;
    captchaExemptCountries?: string[];
  } = {}) {
    const element = document.createElement('lg-phone-input');
    element.setAttribute('data-delivery-methods', JSON.stringify(deliveryMethods));
    element.setAttribute(
      'data-translated-country-code-names',
      JSON.stringify(translatedCountryCodeNames),
    );
    if (captchaExemptCountries) {
      element.setAttribute('data-captcha-exempt-countries', JSON.stringify(captchaExemptCountries));
    }
    element.innerHTML = `
      <script type="application/json" class="phone-input__strings">
        {
          "country_code_label": "Country code",
          "invalid_phone": "Phone number is not valid",
          "unsupported_country": "We are unable to verify phone numbers from %{location}"
        }
      </script>
      <div class="phone-input__international-code-wrapper">
        <label class="usa-label" for="phone_form_international_code">Country code</label>
        ${isSingleOption ? SINGLE_OPTION_HTML : ''}
        ${isNonUSSingleOption ? SINGLE_OPTION_SELECT_NON_US_HTML : ''}
        ${!isSingleOption && !isNonUSSingleOption ? MULTIPLE_OPTIONS_HTML : ''}
      </div>
      <label class="usa-label" for="phone_form_phone">Phone number</label>
      <div class="usa-hint">
        Example:
        <span class="phone-input__example"></span>
      </div>
      <lg-validated-field>
        <script type="application/json" class="validated-field__error-strings">
          {
            "valueMissing": "This field is required"
          }
        </script>
        <input class="phone-input__number validated-field__input" aria-invalid="false" aria-describedby="validated-field-error-298658fb" required="required" aria-required="true" type="tel" id="phone_form_phone" />
      </lg-validated-field>
    `;

    document.body.appendChild(element);

    return element;
  }

  it('initializes with dropdown', () => {
    const input = createAndConnectElement();

    expect(input.querySelector('.iti.iti--allow-dropdown')).to.be.ok();
  });

  it('validates input', async () => {
    const input = createAndConnectElement();

    const phoneNumber = getByLabelText(input, 'Phone number') as HTMLInputElement;

    expect(phoneNumber.validity.valueMissing).to.be.true();

    await userEvent.type(phoneNumber, '5');
    expect(phoneNumber.validationMessage).to.equal('Phone number is not valid');

    await userEvent.type(phoneNumber, '13-555-1234');
    expect(phoneNumber.validity.valid).to.be.true();
  });

  it('validates supported delivery method', async () => {
    const input = createAndConnectElement();

    const phoneNumber = getByLabelText(input, 'Phone number') as HTMLInputElement;
    const countryCode = getByLabelText(input, 'Country code', {
      selector: 'select',
    }) as HTMLSelectElement;

    await userEvent.selectOptions(countryCode, 'LK');
    expect(phoneNumber.validationMessage).to.equal(
      'We are unable to verify phone numbers from Sri Lanka',
    );
  });

  it('formats on country change', async () => {
    const input = createAndConnectElement();

    const phoneNumber = getByLabelText(input, 'Phone number') as HTMLInputElement;
    const countryCode = getByLabelText(input, 'Country code', {
      selector: 'select',
    }) as HTMLSelectElement;

    await userEvent.type(phoneNumber, '071');

    await userEvent.selectOptions(countryCode, 'LK');
    expect(phoneNumber.value).to.equal('+94 071');

    await userEvent.selectOptions(countryCode, 'US');
    expect(phoneNumber.value).to.equal('+1 071');
  });

  context('with single option', () => {
    it('initializes without dropdown', () => {
      const input = createAndConnectElement({ isSingleOption: true });

      expect(input.querySelector('.iti:not(.iti--allow-dropdown)')).to.be.ok();
    });

    it('validates phone from region', async () => {
      const input = createAndConnectElement({ isNonUSSingleOption: true });

      const phoneNumber = getByLabelText(input, 'Phone number') as HTMLInputElement;

      await userEvent.type(phoneNumber, '513-555-1234');
      expect(phoneNumber.validationMessage).to.equal('Phone number is not valid');
    });
  });

  context('with constrained delivery options', () => {
    it('validates supported delivery method', async () => {
      const input = createAndConnectElement({ deliveryMethods: ['voice'] });

      const phoneNumber = getByLabelText(input, 'Phone number') as HTMLInputElement;
      const countryCode = getByLabelText(input, 'Country code', {
        selector: 'select',
      }) as HTMLSelectElement;

      await userEvent.selectOptions(countryCode, 'CA');
      expect(phoneNumber.validationMessage).to.equal(
        'We are unable to verify phone numbers from Canada',
      );
    });
  });

  context('with translated country code names', () => {
    it('renders the translated label', () => {
      createAndConnectElement({ translatedCountryCodeNames: { us: 'Custom USA' } });

      const itiOptionName = document.querySelector('[data-country-code="us"] .iti__country-name')!;

      expect(itiOptionName.textContent).to.equal('Custom USA');
    });
  });

  describe('captcha challenge event handling', () => {
    it('cancels the event', () => {
      createAndConnectElement();

      const event = new CustomEvent(CAPTCHA_EVENT_NAME, { cancelable: true });
      document.dispatchEvent(event);

      expect(event.defaultPrevented).to.be.true();
    });

    it('unbinds event handlers when element is removed', () => {
      sandbox.spy(document, 'addEventListener');
      sandbox.spy(document, 'removeEventListener');
      const element = createAndConnectElement();
      element.parentNode?.removeChild(element);

      const addEventCalls = (document.addEventListener as unknown as SinonStub).callCount;
      const removeEventCalls = (document.removeEventListener as unknown as SinonStub).callCount;

      expect(addEventCalls).to.equal(removeEventCalls);

      const event = new CustomEvent(CAPTCHA_EVENT_NAME, { cancelable: true });
      document.dispatchEvent(event);

      expect(event.defaultPrevented).to.be.false();
    });

    context('without country exemption', () => {
      it('does nothing', async () => {
        const element = createAndConnectElement({ captchaExemptCountries: ['US'] });

        const phoneNumber = getByLabelText(element, 'Phone number') as HTMLInputElement;

        await userEvent.type(phoneNumber, '3065551234');

        const event = new CustomEvent(CAPTCHA_EVENT_NAME, { cancelable: true });
        document.dispatchEvent(event);

        expect(event.defaultPrevented).to.be.false();
      });
    });

    context('with country exemption', () => {
      it('cancels the event', async () => {
        const element = createAndConnectElement({ captchaExemptCountries: ['US'] });

        const phoneNumber = getByLabelText(element, 'Phone number') as HTMLInputElement;

        await userEvent.type(phoneNumber, '5135551234');

        const event = new CustomEvent(CAPTCHA_EVENT_NAME, { cancelable: true });
        document.dispatchEvent(event);

        expect(event.defaultPrevented).to.be.true();
      });
    });
  });
});
