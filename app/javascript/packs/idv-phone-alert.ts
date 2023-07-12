const alertElement = document.getElementById('phone-already-submitted-alert')!;
const input = document.getElementById('idv_phone_form_phone') as HTMLInputElement;
const alreadySubmittedNumbers: string[] = JSON.parse(alertElement.dataset.alreadySubmittedNumbers!);
const iti = window.intlTelInputGlobals.getInstance(input);

input.addEventListener('input', () => {
    const isAlreadySubmittedNumber = alreadySubmittedNumbers.includes(iti.getNumber(intlTelInputUtils.numberFormat.E164));
    alertElement.hidden = !isAlreadySubmittedNumber;
});