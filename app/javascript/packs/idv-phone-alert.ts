const alertElement = document.getElementById('phone-already-submitted-alert')!;
const input = document.getElementById('idv_phone_form_phone') as HTMLInputElement;
const alreadySubmittedNumbers: string[] = JSON.parse(alertElement.dataset.alreadySubmittedNumbers!);

input.addEventListener('input', () => {
    // 513-555-0100
    // (513) 555-0100
    // 5135550100
    // intlTelInput - this.iti
    const isAlreadySubmittedNumber = alreadySubmittedNumbers.includes(input.value);
    alertElement.hidden = !isAlreadySubmittedNumber;
});