import { PhoneFormatter } from 'field-kit';

const INTERNATIONAL_CODE_REGEX = /^\+(\d+) |^1 /;

const I18n = window.LoginGov.I18n;
const phoneFormatter = new PhoneFormatter();

const getPhoneUnsupportedAreaCodeCountry = (areaCode) => {
  const form = document.querySelector('[data-international-phone-form]');
  const phoneUnsupportedAreaCodes = JSON.parse(form.dataset.unsupportedAreaCodes);
  return phoneUnsupportedAreaCodes[areaCode];
};

const areaCodeFromUSPhone = (phone) => {
  const digits = phoneFormatter.digitsWithoutCountryCode(phone);
  if (digits.length >= 10) {
    return digits.slice(0, 3);
  }
  return null;
};

const selectedInternationCodeOption = () => {
  const dropdown = document.querySelector('[data-international-phone-form] .international-code');
  return dropdown.item(dropdown.selectedIndex);
};

const unsupportedUSPhoneOTPDeliveryWarningMessage = (phone) => {
  const areaCode = areaCodeFromUSPhone(phone);
  const country = getPhoneUnsupportedAreaCodeCountry(areaCode);
  if (country) {
    const messageTemplate = I18n.t('devise.two_factor_authentication.otp_delivery_preference.phone_unsupported');
    return messageTemplate.replace('%{location}', country);
  }
  return null;
};

const unsupportedInternationalPhoneOTPDeliveryWarningMessage = () => {
  const selectedOption = selectedInternationCodeOption();
  if (selectedOption.dataset.smsOnly === 'true') {
    const messageTemplate = I18n.t('devise.two_factor_authentication.otp_delivery_preference.phone_unsupported');
    return messageTemplate.replace('%{location}', selectedOption.dataset.countryName);
  }
  return null;
};

const disablePhoneState = (phoneRadio, phoneLabel, smsRadio, deliveryMethodHint, optPhoneLabelInfo,
  warningMessage) => {
  phoneRadio.disabled = true;
  phoneLabel.classList.add('btn-disabled');
  smsRadio.click();
  deliveryMethodHint.innerText = warningMessage;
};

const enablePhoneState = (phoneRadio, phoneLabel, deliveryMethodHint, optPhoneLabelInfo) => {
  phoneRadio.disabled = false;
  phoneLabel.classList.remove('btn-disabled');
  deliveryMethodHint.innerText = I18n.t('devise.two_factor_authentication.otp_delivery_preference.instruction');
  if (optPhoneLabelInfo) {
    optPhoneLabelInfo.innerText = I18n.t('devise.two_factor_authentication.otp_delivery_preference.instruction');
  }
};

const unsupportedPhoneOTPDeliveryWarningMessage = (phone) => {
  const internationCodeOption = selectedInternationCodeOption();
  if (internationCodeOption.dataset.countryCode === '1') {
    return unsupportedUSPhoneOTPDeliveryWarningMessage(phone);
  }
  return unsupportedInternationalPhoneOTPDeliveryWarningMessage();
};

const updateOTPDeliveryMethods = () => {
  const phoneRadio = document.querySelector('[data-international-phone-form] .otp_delivery_preference_voice');
  const smsRadio = document.querySelector('[data-international-phone-form] .otp_delivery_preference_sms');

  if (!(phoneRadio && smsRadio)) {
    return;
  }

  const phoneInput = document.querySelector('[data-international-phone-form] .phone');
  const phoneLabel = phoneRadio.parentNode.parentNode;
  const deliveryMethodHint = document.querySelector('#otp_delivery_preference_instruction');
  const optPhoneLabelInfo = document.querySelector('#otp_phone_label_info');

  const phone = phoneInput.value;

  const warningMessage = unsupportedPhoneOTPDeliveryWarningMessage(phone);
  if (warningMessage) {
    disablePhoneState(phoneRadio, phoneLabel, smsRadio, deliveryMethodHint, optPhoneLabelInfo,
      warningMessage);
  } else {
    enablePhoneState(phoneRadio, phoneLabel, smsRadio, deliveryMethodHint, optPhoneLabelInfo);
  }
};

const internationalCodeFromPhone = (phone) => {
  const match = phone.match(INTERNATIONAL_CODE_REGEX);
  if (match) {
    return match[1] || match[2];
  }
  return '1';
};

const updateInternationalCodeInPhone = (phone, newCode) => {
  if (phone.match(/^\+[^d+]$/)) {
    phone = phone.replace(/^\+[^d+]$/, '');
  }
  if (phone.match(INTERNATIONAL_CODE_REGEX)) {
    return phone.replace(INTERNATIONAL_CODE_REGEX, `+${newCode} `);
  }
  return `+${newCode} ${phone}`;
};

const updateInternationalCodeInput = () => {
  const phoneInput = document.querySelector('[data-international-phone-form] .phone');
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
