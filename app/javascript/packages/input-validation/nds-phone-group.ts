import { parsePhoneNumberFromString } from 'libphonenumber-js';
import type { CountryCode } from 'libphonenumber-js';

const DEFAULT_COUNTRY: CountryCode = 'US';

export const NDS_PHONE_GROUP_SELECTOR = '.usa-phone-input-group[data-nds-phone]';

/** Selected ISO country of an NDS phone group (`.usa-phone-input-group[data-nds-phone]`). */
export const getNdsPhoneGroupCountry = (group: HTMLElement): CountryCode =>
  (group.querySelector<HTMLInputElement>('[data-nds-phone-country]:checked')?.value ||
    DEFAULT_COUNTRY) as CountryCode;

/**
 * E.164 form of the number typed into an NDS phone group, or `undefined` when
 * the current value can't be parsed for the selected country.
 */
export const getNdsPhoneGroupE164 = (group: HTMLElement): string | undefined => {
  const field = group.querySelector<HTMLInputElement>('.usa-phone-input__input');
  const value = field?.value.trim();
  if (!value) {
    return undefined;
  }
  return parsePhoneNumberFromString(value, getNdsPhoneGroupCountry(group))?.number;
};
