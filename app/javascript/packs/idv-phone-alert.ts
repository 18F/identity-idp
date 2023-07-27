import type { PhoneInputElement } from '@18f/identity-phone-input';

const alertElement = document.getElementById('phone-already-submitted-alert')!;
const { iti, textInput: input } = document.querySelector('lg-phone-input') as PhoneInputElement;
const failedPhoneNumbers: string[] = JSON.parse(alertElement.dataset.failedPhoneNumbers!);

input.addEventListener('input', () => {
  const isFailedPhoneNumber = failedPhoneNumbers.includes(
    iti.getNumber(intlTelInputUtils.numberFormat.E164),
  );
  alertElement.hidden = !isFailedPhoneNumber;
});
