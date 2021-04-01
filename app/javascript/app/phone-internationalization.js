const INTERNATIONAL_CODE_REGEX = /^\+(\d+) |^1 /;

// @ts-ignore
const { I18n } = window.LoginGov;

const selectedInternationCodeOption = () => {
  const dropdown = /** @type {HTMLSelectElement} */ (document.querySelector(
    '[data-international-phone-form] .international-code',
  ));
  return /** @type {HTMLOptionElement} */ (dropdown.item(dropdown.selectedIndex));
};

const setRadioEnabled = (radio, isEnabled) => {
  radio.disabled = !isEnabled;

  const label = /** @type {Element} */ radio.parentNode.parentNode;

  label.classList.toggle('usa-button--disabled', !isEnabled);
};

const updateOTPDeliveryMethods = () => {
  const phoneRadio = document.querySelector(
    '[data-international-phone-form] .otp_delivery_preference_voice',
  );
  const smsRadio = /** @type {HTMLElement} */ (document.querySelector(
    '[data-international-phone-form] .otp_delivery_preference_sms',
  ));

  if (!(phoneRadio && smsRadio)) {
    return;
  }

  const deliveryMethodHint = /** @type {HTMLElement} */ (document.querySelector(
    '#otp_delivery_preference_instruction',
  ));
  const selectedOption = selectedInternationCodeOption();

  const supportsSms = selectedOption.dataset.supportsSms === 'true';
  const supportsVoice = selectedOption.dataset.supportsVoice === 'true';

  setRadioEnabled(smsRadio, supportsSms);
  setRadioEnabled(phoneRadio, supportsVoice);

  if (supportsVoice) {
    deliveryMethodHint.innerText = I18n.t(
      'two_factor_authentication.otp_delivery_preference.instruction',
    );
  } else {
    smsRadio.click();
    deliveryMethodHint.innerText = I18n.t(
      'two_factor_authentication.otp_delivery_preference.phone_unsupported',
    ).replace('%{location}', selectedOption.dataset.countryName);
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
