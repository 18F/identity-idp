import { t } from '@18f/identity-i18n';

const selector = document.getElementById('in_person_address_state');

selector?.addEventListener('change', (event) => {
  if (event?.target?.value === 'PR') {
    const hints = document.querySelectorAll('.usa-hint');
    const firstHint = hints[0];
    const secondHint = hints[1];
    firstHint.textContent = `${t('forms.example')} 150 Calle A Apt 3`;
    secondHint.textContent = `${t('forms.example')} URB Las Gladiolas`;
  }
});
