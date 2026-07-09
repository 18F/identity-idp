export function showOrHideJurisdictionExtras(jurisdictionCode) {
  const hasJurisdictionSpecificHint =
    jurisdictionCode &&
    document.querySelectorAll(`.jurisdiction-extras [data-state=${jurisdictionCode}]`).length > 0;
  
  document.querySelectorAll<HTMLElement>(`.jurisdiction-extras [data-state]`).forEach((element) => {
    const shouldShow =
      element.dataset.state === jurisdictionCode ||
      (!hasJurisdictionSpecificHint && element.dataset.state === 'default');
    element.classList.toggle('display-none', !shouldShow);
  });
  showOrHideExpirationDateField(jurisdictionCode);
}

export function showOrHideExpirationDateField(jurisdictionCode) {
  const idExpirationDiv = document.querySelector('.id_expiration');
  // get hidden field value for class skip-state-id-expiration
  const skipStateIdExpiration = document.querySelector('.skip-state-id-expiration')?.value;
  console.log('jurisdictionCode', jurisdictionCode);
  console.log('skipStateIdExpiration: ', skipStateIdExpiration);
  if (idExpirationDiv && skipStateIdExpiration) {
    if (skipStateIdExpiration.includes(jurisdictionCode)) {
      idExpirationDiv.classList.add('display-none');
    } else {
      idExpirationDiv.classList.remove('display-none');
    }
  }
}

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

onStateSelectionChange();
onIdentityDocStateSelection();
onIdentityDocJurisdictionSelection();
