const alertElement = document.getElementById('phone-already-submitted-alert')!;
const input = document.getElementById('idv_phone_form_phone') as HTMLInputElement;
const failedPhoneNumbers: string[] = JSON.parse(alertElement.dataset.failedPhoneNumbers!);
const iti = window.intlTelInputGlobals.getInstance(input);

input.addEventListener('input', () => {
    const isFailedPhoneNumber = failedPhoneNumbers.includes(iti.getNumber(intlTelInputUtils.numberFormat.E164));
    alertElement.hidden = !isFailedPhoneNumber;
});