import { PhoneFormatter } from 'field-kit';

const I18n = window.LoginGov.I18n;
const phoneFormatter = new PhoneFormatter();

const getPhoneUnsupportedAreaCodeCountry = (areaCode) => {
  const form = document.querySelector('#new_two_factor_setup_form');
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
  const dropdown = document.querySelector('#two_factor_setup_form_international_code');
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

const unsupportedPhoneOTPDeliveryWarningMessage = (phone) => {
  const internationCodeOption = selectedInternationCodeOption();
  if (internationCodeOption.dataset.countryCode === '1') {
    return unsupportedUSPhoneOTPDeliveryWarningMessage(phone);
  }
  return unsupportedInternationalPhoneOTPDeliveryWarningMessage();
};

const updateOTPDeliveryMethods = () => {
  const phoneInput = document.querySelector('#two_factor_setup_form_phone');
  const phoneRadio = document.querySelector('#two_factor_setup_form_otp_delivery_preference_voice');
  const smsRadio = document.querySelector('#two_factor_setup_form_otp_delivery_preference_sms');
  const phoneLabel = phoneRadio.parentNode.parentNode;
  const deliveryMethodHint = document.querySelector('#otp_delivery_preference_instruction');
  const optPhoneLabelInfo = document.querySelector('#otp_phone_label_info');

  const phone = phoneInput.value;

  const warningMessage = unsupportedPhoneOTPDeliveryWarningMessage(phone);
  if (warningMessage) {
    phoneRadio.disabled = true;
    phoneLabel.classList.add('btn-disabled');
    smsRadio.click();
    deliveryMethodHint.innerText = warningMessage;
    optPhoneLabelInfo.innerText = I18n.t('devise.two_factor_authentication.otp_phone_label_info_modile_only');
  } else {
    phoneRadio.disabled = false;
    phoneLabel.classList.remove('btn-disabled');
    deliveryMethodHint.innerText = I18n.t('devise.two_factor_authentication.otp_delivery_preference.instruction');
    optPhoneLabelInfo.innerText = I18n.t('devise.two_factor_authentication.otp_phone_label_info');
  }
};

document.addEventListener('DOMContentLoaded', () => {
  const phoneInput = document.querySelector('#two_factor_setup_form_phone');
  const codeInput = document.querySelector('#two_factor_setup_form_international_code');
  if (phoneInput) {
    phoneInput.addEventListener('keyup', updateOTPDeliveryMethods);
  }
  if (codeInput) {
    codeInput.addEventListener('change', updateOTPDeliveryMethods);
    updateOTPDeliveryMethods();
  }
});
