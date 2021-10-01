const INTERNATIONAL_CODE_REGEX = /^\+(\d+) |^1 /;

/**
 * @typedef {typeof window & {
 *   LoginGov: { I18n: import('@18f/identity-i18n').I18n } }
 * } GlobalWithLoginGov
 */

const { t } = /** @type {GlobalWithLoginGov} */ (window).LoginGov.I18n;

const selectedInternationCodeOption = () => {
  const dropdown = /** @type {HTMLSelectElement} */ (document.querySelector(
    '[data-international-phone-form] .international-code',
  ));
  return /** @type {HTMLOptionElement} */ (dropdown.item(dropdown.selectedIndex));
};

/**
 * @return {HTMLInputElement[]}
 */
const getOTPDeliveryMethods = () =>
  Array.from(document.querySelectorAll('.js-otp-delivery-preference'));

/**
 * Returns true if the delivery option is valid for the selected option, or false otherwise.
 *
 * @param {string} delivery
 * @return {boolean}
 */
const isDeliveryOptionSupported = (delivery) =>
  selectedInternationCodeOption().getAttribute(`data-supports-${delivery}`) !== 'false';

/**
 * @param {string} delivery
 * @return {string=}
 */
const getHintTextForDisabledDeliveryOption = (delivery) =>
  // i18n-tasks-use t('two_factor_authentication.otp_delivery_preference.voice_unsupported')
  // i18n-tasks-use t('two_factor_authentication.otp_delivery_preference.sms_unsupported')
  t(`two_factor_authentication.otp_delivery_preference.${delivery}_unsupported`, {
    location: /** @type {string} */ (selectedInternationCodeOption().dataset.countryName),
  });

/**
 * @param {string=} hintText
 */
function setHintText(
  hintText = t('two_factor_authentication.otp_delivery_preference.instruction'),
) {
  const hintElement = document.querySelector('#otp_delivery_preference_instruction');
  if (hintElement) {
    hintElement.textContent = hintText;
  }
}

/**
 * Returns true if all inputs are disabled, or false otherwise.
 *
 * @param {HTMLInputElement[]} inputs
 * @return {boolean}
 */
const isAllDisabled = (inputs) => inputs.every((input) => input.disabled);

/**
 * Returns the next non-disabled input in the set of inputs, if one exists.
 *
 * @param {HTMLInputElement[]} inputs
 * @return {HTMLInputElement=}
 */
const getFirstEnabledInput = (inputs) => inputs.find((input) => !input.disabled);

const updateOTPDeliveryMethods = () => {
  const methods = getOTPDeliveryMethods();
  setHintText();

  methods.forEach((method) => {
    const delivery = method.value;
    const isSupported = isDeliveryOptionSupported(delivery);
    method.disabled = !isSupported;
    if (!isSupported) {
      setHintText(getHintTextForDisabledDeliveryOption(delivery));

      if (method.checked) {
        method.checked = false;
        const nextEnabledInput = getFirstEnabledInput(methods);
        if (nextEnabledInput) {
          nextEnabledInput.checked = true;
        }
      }
    }
  });

  if (isAllDisabled(methods)) {
    const hintText = t('two_factor_authentication.otp_delivery_preference.no_supported_options', {
      location: /** @type {string} */ (selectedInternationCodeOption().dataset.countryName),
    });

    setHintText(hintText);
  }
};

const internationalCodeFromPhone = (phone) => {
  const match = phone.match(INTERNATIONAL_CODE_REGEX);
  if (match) {
    return match[1] || match[2];
  }
  return '1';
};

const updateInternationalCodeInPhone = (phone, newCode) =>
  phone.replace(new RegExp(`^\\+?(\\d+\\s+|${newCode})?`), `+${newCode} `);

const updateInternationalCodeInput = () => {
  const phoneInput = /** @type {HTMLInputElement} */ (document.querySelector(
    '[data-international-phone-form] .phone',
  ));
  const phone = phoneInput.value;
  const inputInternationalCode = internationalCodeFromPhone(phone);
  const selectedInternationalCode = selectedInternationCodeOption().dataset.countryCode;

  if (inputInternationalCode !== selectedInternationalCode) {
    phoneInput.value = updateInternationalCodeInPhone(phone, selectedInternationalCode);
  }
};

document.addEventListener('DOMContentLoaded', () => {
  const phoneInput = document.querySelector('[data-international-phone-form] .phone');
  const codeInput = document.querySelector('[data-international-phone-form] .international-code');
  if (phoneInput) {
    phoneInput.addEventListener('countryChange', updateOTPDeliveryMethods);
  }
  if (codeInput) {
    codeInput.addEventListener('change', updateOTPDeliveryMethods);
    codeInput.addEventListener('change', updateInternationalCodeInput);
    updateOTPDeliveryMethods();
  }
});
