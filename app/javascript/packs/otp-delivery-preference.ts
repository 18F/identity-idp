import { t } from '@18f/identity-i18n';

/**
 * Returns the OTP delivery preference element.
 */
const getOTPDeliveryMethodContainer = (): HTMLElement =>
  document.querySelector<HTMLElement>('.js-otp-delivery-preferences .ads-radio-group')!;

const getOTPDeliveryMethods = () =>
  Array.from(document.querySelectorAll<HTMLInputElement>('.js-otp-delivery-preference'));

/**
 * Returns true if the delivery option is valid for the selected option, or false otherwise.
 */
const isDeliveryOptionSupported = (delivery: string, selectedOption: HTMLOptionElement): boolean =>
  selectedOption.getAttribute(`data-supports-${delivery}`) !== 'false';

const getHintTextForDisabledDeliveryOption = (
  delivery: string,
  location: string,
): string | undefined =>
  // i18n-tasks-use t('two_factor_authentication.otp_delivery_preference.voice_unsupported')
  // i18n-tasks-use t('two_factor_authentication.otp_delivery_preference.sms_unsupported')
  t(`two_factor_authentication.otp_delivery_preference.${delivery}_unsupported`, { location });

function setHintText(hintText?: string) {
  const hintElement = document.querySelector<HTMLElement>('#otp_delivery_preference_instruction');
  if (hintElement) {
    hintElement.textContent = hintText || '';
    hintElement.toggleAttribute('hidden', !hintText);
  }
}

/**
 * Returns true if all inputs are disabled, or false otherwise.
 */
const isAllDisabled = (inputs: HTMLInputElement[]): boolean =>
  inputs.every((input) => input.disabled);

/**
 * Returns the next non-disabled input in the set of inputs, if one exists.
 */
const getFirstEnabledInput = (inputs: HTMLInputElement[]): HTMLInputElement | undefined =>
  inputs.find((input) => !input.disabled);

/**
 * Toggles the delivery preferences selection visible or hidden.
 *
 * @param isVisible Whether the selection element should be visible.
 */
const toggleDeliveryPreferencesVisible = (isVisible: boolean) =>
  getOTPDeliveryMethodContainer().toggleAttribute('hidden', !isVisible);

function updateOTPDeliveryMethods(select: HTMLSelectElement) {
  const selectedOption = select.options[select.selectedIndex];
  const methods = getOTPDeliveryMethods();
  setHintText();

  const location = selectedOption.dataset.countryName!;

  methods.forEach((method) => {
    const delivery = method.value;
    const isSupported = isDeliveryOptionSupported(delivery, selectedOption);
    method.disabled = !isSupported || method.dataset.vendorOutage === 'true';
    if (!isSupported) {
      setHintText(getHintTextForDisabledDeliveryOption(delivery, location));
    }

    if (method.disabled && method.checked) {
      method.checked = false;
      const nextEnabledInput = getFirstEnabledInput(methods);
      if (nextEnabledInput) {
        nextEnabledInput.checked = true;
      }
    }
  });

  const isAllMethodsDisabled = isAllDisabled(methods);
  const isAllMethodsUnsupported = methods.every(
    (method) => !isDeliveryOptionSupported(method.value, selectedOption),
  );
  if (isAllMethodsUnsupported) {
    setHintText(
      t('two_factor_authentication.otp_delivery_preference.no_supported_options', { location }),
    );
  }
  toggleDeliveryPreferencesVisible(!isAllMethodsDisabled);
}

document.querySelectorAll<HTMLSelectElement>('[data-ads-phone-country]').forEach((select) => {
  select.addEventListener('change', () => updateOTPDeliveryMethods(select));
  updateOTPDeliveryMethods(select);
});
