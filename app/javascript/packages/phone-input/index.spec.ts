import { getByLabelText, getByRole, getAllByRole } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { computeAccessibleName } from 'dom-accessibility-api';
import type { SinonStub } from 'sinon';
import * as analytics from '@18f/identity-analytics';
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

  beforeEach(() => {
    sandbox.stub(analytics, 'trackEvent');
  });

  function createAndConnectElement({
    isUSSingleOption = false,
    isInternationalSingleOption = false,
    deliveryMethods = ['sms', 'voice'],
    translatedCountryCodeNames = {},
    captchaExemptCountries = undefined,
    phoneInputValue = undefined,
  }: {
    isUSSingleOption?: boolean;
    isInternationalSingleOption?: Boolean;
    deliveryMethods?: string[];
    translatedCountryCodeNames?: Record<string, string>;
    captchaExemptCountries?: string[];
    phoneInputValue?: string;
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

    const phoneInput = document.createElement('input');
    phoneInput.type = 'tel';
    phoneInput.id = 'phone_form_phone';
    phoneInput.className = 'phone-input__number validated-field__input';
    phoneInput.setAttribute('value', phoneInputValue ?? '');
    phoneInput.setAttribute('aria-invalid', 'false');
    phoneInput.setAttribute('aria-describedby', 'validated-field-error-298658fb');
    phoneInput.setAttribute('required', 'required');

    element.innerHTML = `
      <script type="application/json" class="phone-input__strings">
        {
          "country_code_label": "Country code",
          "invalid_phone_us": "Enter a 10 digit phone number.",
          "invalid_phone_international": "Enter a phone number with the correct number of digits.",
          "unsupported_country": "We are unable to verify phone numbers from %{location}"
        }
      </script>
      <div class="phone-input__international-code-wrapper">
        <label class="usa-label" for="phone_form_international_code">Country code</label>
        ${isUSSingleOption ? SINGLE_OPTION_HTML : ''}
        ${isInternationalSingleOption ? SINGLE_OPTION_SELECT_NON_US_HTML : ''}
        ${!isUSSingleOption && !isInternationalSingleOption ? MULTIPLE_OPTIONS_HTML : ''}
      </div>
      <label class="usa-label" for="phone_form_phone">Phone number</label>
      <lg-validated-field>
        <script type="application/json" class="validated-field__error-strings">
          {
            "valueMissing": "This field is required"
          }
        </script>
        ${phoneInput.outerHTML}
      </lg-validated-field>
    `;

    document.body.appendChild(element);

    return element;
  }

  it('initializes with dropdown', () => {
    const input = createAndConnectElement();

    expect(input.querySelector('.iti.iti--allow-dropdown')).to.be.ok();
  });

  context('with US phone number', () => {
    it('validates input', async () => {
      const input = createAndConnectElement();
      const phoneNumber = getByLabelText(input, 'Phone number') as HTMLInputElement;

      expect(phoneNumber.validity.valueMissing).to.be.true();

      await userEvent.type(phoneNumber, '5');
      expect(phoneNumber.validationMessage).to.equal('Enter a 10 digit phone number.');

      await userEvent.type(phoneNumber, '13-555-1234');
      expect(phoneNumber.validity.valid).to.be.true();
    });
  });

  context('with international phone number', () => {
    it('validates input', async () => {
      const input = createAndConnectElement();

      const phoneNumber = getByLabelText(input, 'Phone number') as HTMLInputElement;
      const countryCode = getByLabelText(input, 'Country code', {
        selector: 'select',
      }) as HTMLSelectElement;

      expect(phoneNumber.validity.valueMissing).to.be.true();

      await userEvent.type(phoneNumber, '647');
      expect(countryCode.value).to.eql('CA');
      expect(phoneNumber.validationMessage).to.equal(
        'Enter a phone number with the correct number of digits.',
      );

      await userEvent.type(phoneNumber, '555-1234');
      expect(phoneNumber.validity.valid).to.be.true();
    });
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

  it('sets country on initialization', () => {
    const input = createAndConnectElement({
      phoneInputValue: '+12502345678',
    });
    const countryCode = getByLabelText(input, 'Country code', {
      selector: 'select',
    }) as HTMLSelectElement;
    expect(countryCode.value).to.eql('CA');
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

  it('tracks event on country change', async () => {
    const input = createAndConnectElement();
    const iti = input.querySelector('.iti') as HTMLElement;

    const phoneNumber = getByLabelText(input, 'Phone number') as HTMLInputElement;

    await userEvent.type(phoneNumber, '+1306');
    expect(analytics.trackEvent).to.have.been.calledOnceWith('phone_input_country_changed', {
      country_code: 'CA',
    });

    const dropdownButton = getByRole(iti, 'combobox', { name: 'Country code' });
    await userEvent.click(dropdownButton);
    const usOption = getByRole(iti, 'option', { name: 'United States +1' });
    await userEvent.click(usOption);
    expect(analytics.trackEvent).to.have.been.calledWith('phone_input_country_changed', {
      country_code: 'US',
    });

    await userEvent.clear(phoneNumber);
    await userEvent.type(phoneNumber, '+6');
    expect(analytics.trackEvent).to.have.callCount(2);
  });

  it('renders as an accessible combobox', () => {
    const phoneInput = createAndConnectElement();
    const comboboxes = getAllByRole(phoneInput, 'combobox');
    const listbox = getByRole(phoneInput, 'listbox');

    // There are two comboboxes, one for no-JavaScript, and the other JavaScript enhanced. Only one
    // is visible at a time. We're primarily concerned with testing the latter.
    expect(comboboxes).to.have.lengthOf(2);
    const [combobox] = comboboxes.filter(
      (element) => !element.closest('.phone-input__international-code-wrapper'),
    );

    const hasPopup = combobox.getAttribute('aria-haspopup');
    const name = computeAccessibleName(combobox);
    // > Otherwise, the value of the `combobox` is represented by its descendant elements and can be
    // > determined using the same method used to compute the name of a `button` from its descendant
    // > content.
    //
    // See: https://w3c.github.io/aria/#combobox
    const value = combobox.textContent;
    const controlled = document.getElementById(combobox.getAttribute('aria-controls')!);

    // "listbox" is the default value for a combobox role.
    //
    // > Elements with the role `combobox` have an implicit `aria-haspopup` value of `listbox`.
    //
    // See: https://w3c.github.io/aria/#combobox
    //
    // Ideally this could infer based on browser default behavior via e.g. ARIA reflection, but it
    // is not (yet) supported in JSDOM.
    //
    // See: https://github.com/jsdom/jsdom/issues/3323
    expect(hasPopup).to.be.oneOf([null, 'listbox']);
    expect(name).to.equal('Country code');
    expect(value).to.equal('United States: +1');
    expect(controlled).to.equal(listbox);
  });

  context('with single option', () => {
    it('initializes without dropdown', () => {
      const input = createAndConnectElement({ isUSSingleOption: true });

      expect(input.querySelector('.iti:not(.iti--allow-dropdown)')).to.be.ok();
    });

    it('validates phone from region', async () => {
      const input = createAndConnectElement({ isInternationalSingleOption: true });

      const phoneNumber = getByLabelText(input, 'Phone number') as HTMLInputElement;

      await userEvent.type(phoneNumber, '5135551234');
      expect(phoneNumber.validationMessage).to.equal(
        'Enter a phone number with the correct number of digits.',
      );
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
