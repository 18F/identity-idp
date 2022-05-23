import { getByLabelText } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';

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
  before(async () => {
    await import('intl-tel-input/build/js/utils.js');
    window.intlTelInputUtils = global.intlTelInputUtils;
    const { PhoneInput } = await import('./index.js');
    customElements.define('lg-phone-input', PhoneInput);
  });

  function createAndConnectElement({
    isSingleOption = false,
    isNonUSSingleOption = false,
    deliveryMethods = ['sms', 'voice'],
    translatedCountryCodeNames = {},
  } = {}) {
    const element = document.createElement('lg-phone-input');
    element.setAttribute('data-delivery-methods', JSON.stringify(deliveryMethods));
    element.setAttribute(
      'data-translated-country-code-names',
      JSON.stringify(translatedCountryCodeNames),
    );
    element.innerHTML = `
      <script type="application/json" class="phone-input__strings">
        {
          "country_code_label": "Country code",
          "invalid_phone": "Phone number is not valid",
          "country_constraint_usa": "Must be a U.S. phone number",
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

    /** @type {HTMLInputElement} */
    const phoneNumber = getByLabelText(input, 'Phone number');

    expect(phoneNumber.validity.valueMissing).to.be.true();

    await userEvent.type(phoneNumber, '5');
    expect(phoneNumber.validationMessage).to.equal('Phone number is not valid');

    await userEvent.type(phoneNumber, '13-555-1234');
    expect(phoneNumber.validity.valid).to.be.true();
  });

  it('validates supported delivery method', async () => {
    const input = createAndConnectElement();

    /** @type {HTMLInputElement} */
    const phoneNumber = getByLabelText(input, 'Phone number');
    /** @type {HTMLSelectElement} */
    const countryCode = getByLabelText(input, 'Country code', { selector: 'select' });

    await userEvent.selectOptions(countryCode, 'LK');
    expect(phoneNumber.validationMessage).to.equal(
      'We are unable to verify phone numbers from Sri Lanka',
    );
  });

  it('formats on country change', async () => {
    const input = createAndConnectElement();

    /** @type {HTMLInputElement} */
    const phoneNumber = getByLabelText(input, 'Phone number');
    /** @type {HTMLSelectElement} */
    const countryCode = getByLabelText(input, 'Country code', { selector: 'select' });

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
      const input = createAndConnectElement({ isSingleOption: true });

      /** @type {HTMLInputElement} */
      const phoneNumber = getByLabelText(input, 'Phone number');

      await userEvent.type(phoneNumber, '306-555-1234');
      expect(phoneNumber.validationMessage).to.equal('Must be a U.S. phone number');
    });

    context('with non-U.S. single option', () => {
      it('validates phone from region', async () => {
        const input = createAndConnectElement({ isNonUSSingleOption: true });

        /** @type {HTMLInputElement} */
        const phoneNumber = getByLabelText(input, 'Phone number');

        await userEvent.type(phoneNumber, '513-555-1234');
        expect(phoneNumber.validationMessage).to.equal('Phone number is not valid');
      });
    });
  });

  context('with constrained delivery options', () => {
    it('validates supported delivery method', async () => {
      const input = createAndConnectElement({ deliveryMethods: ['voice'] });

      /** @type {HTMLInputElement} */
      const phoneNumber = getByLabelText(input, 'Phone number');
      /** @type {HTMLSelectElement} */
      const countryCode = getByLabelText(input, 'Country code', { selector: 'select' });

      await userEvent.selectOptions(countryCode, 'CA');
      expect(phoneNumber.validationMessage).to.equal(
        'We are unable to verify phone numbers from Canada',
      );
    });
  });

  context('with translated country code names', () => {
    it('renders the translated label', () => {
      createAndConnectElement({ translatedCountryCodeNames: { us: 'Custom USA' } });

      const itiOptionName = document.querySelector('[data-country-code="us"] .iti__country-name');

      expect(itiOptionName.textContent).to.equal('Custom USA');
    });
  });
});
