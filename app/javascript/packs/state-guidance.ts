import { t } from '@18f/identity-i18n';

export function showOrHidePuertoRicoExtras(forStateCode) {
  const isPuertoRico = forStateCode === 'PR';

  document.querySelectorAll('.puerto-rico-extras').forEach((element) => {
    if (isPuertoRico) {
      element.classList.remove('display-none');
    } else {
      element.classList.add('display-none');
    }
  });
}

export function showOrHideJurisdictionExtras(forJurisdictionCode) {
  document.querySelectorAll('.jurisdiction-extras').forEach((element) => {
    switch (forJurisdictionCode) {
      case 'TX':
        element.innerHTML = t('in_person_proofing.form.state_id.state_id_number_texas_hint');
        break;
      case 'FL':
        element.innerHTML = t('in_person_proofing.form.state_id.state_id_number_hint_html');
        break;
      default:
        element.innerHTML = t('in_person_proofing.form.state_id.state_id_number_hint_html');
    }
  });
}

function onStateSelectionChange() {
  const stateSelector: HTMLInputElement = <HTMLInputElement>(
    document.getElementById('idv_form_state')
  );
  showOrHidePuertoRicoExtras(stateSelector?.value);
  showOrHideJurisdictionExtras(stateSelector?.value);
}

function onIdentityDocStateSelection() {
  const stateSelectors = document.querySelectorAll('.address-state-selector');
  stateSelectors.forEach((stateSelector) => {
    if (stateSelector instanceof HTMLSelectElement) {
      stateSelector.addEventListener('change', () =>
        showOrHidePuertoRicoExtras(stateSelector.value),
      );
      showOrHidePuertoRicoExtras(stateSelector.value);
    }
  });
}

function onIdentityDocJurisdictionSelection() {
  const stateSelectors = document.querySelectorAll('.jurisdiction-state-selector');
  stateSelectors.forEach((stateSelector) => {
    if (stateSelector instanceof HTMLSelectElement) {
      stateSelector.addEventListener('change', () =>
        showOrHideJurisdictionExtras(stateSelector.value),
      );
      showOrHideJurisdictionExtras(stateSelector.value);
    }
  });
}

document.getElementById('idv_form_state')?.addEventListener('change', onStateSelectionChange);

document.addEventListener('DOMContentLoaded', () => {
  onStateSelectionChange();
  onIdentityDocStateSelection();
  onIdentityDocJurisdictionSelection();
});
