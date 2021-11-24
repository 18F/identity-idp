/** @typedef {import('@18f/identity-phone-input').PhoneInput} PhoneInput */

/**
 * @typedef {typeof window & {
 *   LoginGov: { I18n: import('@18f/identity-i18n').I18n } }
 * } GlobalWithLoginGov
 */

const { t } = /** @type {GlobalWithLoginGov} */ (window).LoginGov.I18n;

/**
 * Returns the OTP delivery preference element.
 *
 * @return {HTMLElement}
 */
const getOTPDeliveryMethodContainer = () =>
  /** @type {HTMLElement} */ (document.querySelector('.js-otp-delivery-preferences'));

/**
 * @return {HTMLInputElement[]}
 */
const getOTPDeliveryMethods = () =>
  Array.from(document.querySelectorAll('.js-otp-delivery-preference'));

/**
 * Returns true if the delivery option is valid for the selected option, or false otherwise.
 *
 * @param {string} delivery
 * @param {HTMLOptionElement} selectedOption
 * @return {boolean}
 */
const isDeliveryOptionSupported = (delivery, selectedOption) =>
  selectedOption.getAttribute(`data-supports-${delivery}`) !== 'false';

/**
 * @param {string} delivery
 * @param {string} location
 * @return {string=}
 */
const getHintTextForDisabledDeliveryOption = (delivery, location) =>
  // i18n-tasks-use t('two_factor_authentication.otp_delivery_preference.voice_unsupported')
  // i18n-tasks-use t('two_factor_authentication.otp_delivery_preference.sms_unsupported')
  t(`two_factor_authentication.otp_delivery_preference.${delivery}_unsupported`, { location });

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

/**
 * Toggles the delivery preferences selection visible or hidden.
 *
 * @param {boolean} isVisible Whether the selection element should be visible.
 */
const toggleDeliveryPreferencesVisible = (isVisible) =>
  getOTPDeliveryMethodContainer().classList.toggle('display-none', !isVisible);

/**
 * @param {Event} event
 */
function updateOTPDeliveryMethods(event) {
  if (!(event.target instanceof HTMLSelectElement)) {
    return;
  }

  const { target: select, currentTarget } = event;
  const { textInput } = /** @type {PhoneInput} */ (currentTarget);
  if (!textInput) {
    return;
  }

  const selectedOption = select.options[select.selectedIndex];
  const methods = getOTPDeliveryMethods();
  setHintText();

  const location = /** @type {string} */ (selectedOption.dataset.countryName);

  methods.forEach((method) => {
    const delivery = method.value;
    const isSupported = isDeliveryOptionSupported(delivery, selectedOption);
    method.disabled = !isSupported;
    if (!isSupported) {
      setHintText(getHintTextForDisabledDeliveryOption(delivery, location));

      if (method.checked) {
        method.checked = false;
        const nextEnabledInput = getFirstEnabledInput(methods);
        if (nextEnabledInput) {
          nextEnabledInput.checked = true;
        }
      }
    }
  });

  const isAllMethodsDisabled = isAllDisabled(methods);
  toggleDeliveryPreferencesVisible(!isAllMethodsDisabled);
}

document.querySelectorAll('lg-phone-input').forEach((node) => {
  const phoneInput = /** @type {PhoneInput} */ (node);
  phoneInput.addEventListener('change', updateOTPDeliveryMethods);
});
