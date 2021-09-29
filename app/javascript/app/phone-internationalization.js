const INTERNATIONAL_CODE_REGEX = /^\+(\d+) |^1 /;

// @ts-ignore
const { I18n } = window.LoginGov;

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
function getHintTextForDisabledDeliveryOption(delivery) {
  // i18n-tasks-use t('two_factor_authentication.otp_delivery_preference.voice_unsupported')
  // i18n-tasks-use t('two_factor_authentication.otp_delivery_preference.sms_unsupported')
  let hintText = I18n.t(
    `two_factor_authentication.otp_delivery_preference.${delivery}_unsupported`,
  );

  if (hintText) {
    const location = selectedInternationCodeOption().dataset.countryName;
    hintText = hintText.replace('%{location}', location);
  }

  return hintText;
}

/**
 * @param {string=} hintText
 */
function setHintText(
  hintText = I18n.t('two_factor_authentication.otp_delivery_preference.instruction'),
) {
  const hintElement = document.querySelector('#otp_delivery_preference_instruction');
  if (hintElement) {
    hintElement.textContent = hintText;
  }
}

/**
 * Returns the next non-disabled input in the set of inputs, if one exists.
 *
 * @param {HTMLInputElement[]} inputs
 * @param {number} index
 * @return {HTMLInputElement=}
 */
const getNextEnabledInput = (inputs, index) =>
  [...inputs.slice(index + 1), ...inputs.slice(0, index)].find((input) => !input.disabled);

const updateOTPDeliveryMethods = () => {
  const methods = getOTPDeliveryMethods();
  setHintText();

  methods.forEach((method, index) => {
    const delivery = method.value;
    const isSupported = isDeliveryOptionSupported(delivery);
    method.disabled = !isSupported;
    if (!isSupported) {
      setHintText(getHintTextForDisabledDeliveryOption(delivery));

      if (method.checked) {
        method.checked = false;
        const nextEnabledInput = getNextEnabledInput(methods, index);
        if (nextEnabledInput) {
          nextEnabledInput.checked = true;
        }
      }
    }
  });
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
