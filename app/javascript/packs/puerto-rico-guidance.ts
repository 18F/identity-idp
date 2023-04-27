function showOrHidePuertoRicoExtras(forStateCode) {
  const isPuertoRico = forStateCode === 'PR';

  document.querySelectorAll('.puerto-rico-extras').forEach((element) => {
    element.classList.toggle('display-none', !isPuertoRico);
  });
}

function onStateSelectionChange() {
  const stateSelector: HTMLInputElement = <HTMLInputElement>(
    document.getElementById('idv_form_state')
  );
  showOrHidePuertoRicoExtras(stateSelector?.value);
}

function onIdentityDocStateSelectionChange() {
  const identityDocStateSelector: HTMLInputElement = <HTMLInputElement>(
    document.getElementById('state_id_identity_doc_address_state')
  );
  showOrHidePuertoRicoExtras(identityDocStateSelector?.value);
}

function onAddressStateSelectionChange() {
  const addressStateSelector: HTMLInputElement = <HTMLInputElement>(
    document.getElementById('in_person_address_state')
  );
  showOrHidePuertoRicoExtras(addressStateSelector?.value);
}

function onUpdateStateId() {
  const updateIdentityDocStateSelector: HTMLInputElement = <HTMLInputElement>(
    document.getElementById('state_id_identity_doc_address_state')
  );
  showOrHidePuertoRicoExtras(updateIdentityDocStateSelector?.value);
}

function onUpdateAddress() {
  const updateAddressStateSelector: HTMLInputElement = <HTMLInputElement>(
    document.getElementById('in_person_address_state')
  );
  showOrHidePuertoRicoExtras(updateAddressStateSelector?.value);
}

function onUpdate() {
  const { pathname } = window.location;

  if (pathname === '/verify/in_person/state_id') {
    onUpdateStateId();
  }
  if (pathname === '/verify/in_person/address') {
    onUpdateAddress();
  }
}

document.getElementById('idv_form_state')?.addEventListener('change', onStateSelectionChange);
document
  .getElementById('state_id_identity_doc_address_state')
  ?.addEventListener('change', onIdentityDocStateSelectionChange);
document
  .getElementById('in_person_address_state')
  ?.addEventListener('change', onAddressStateSelectionChange);

// set initial visibility
onStateSelectionChange();
onIdentityDocStateSelectionChange();
onAddressStateSelectionChange();

onUpdate();
