import { parsePhoneNumberFromString } from 'libphonenumber-js';
import type { CountryCode } from 'libphonenumber-js';

const alertElement = document.getElementById('phone-already-submitted-alert')!;
const phoneField = document.querySelector<HTMLInputElement>('[data-ads-phone-input]')!;
const countrySelect = phoneField
  .closest('.ads-input')
  ?.querySelector<HTMLSelectElement>('[data-ads-phone-country]');
const failedPhoneNumbers: string[] = JSON.parse(alertElement.dataset.failedPhoneNumbers!);

const currentE164 = () => {
  const parsed = parsePhoneNumberFromString(
    phoneField.value,
    (countrySelect?.value || 'US') as CountryCode,
  );
  return parsed?.format('E.164') ?? '';
};

const syncAlert = () => {
  alertElement.hidden = !failedPhoneNumbers.includes(currentE164());
};

phoneField.addEventListener('input', syncAlert);
countrySelect?.addEventListener('change', syncAlert);
