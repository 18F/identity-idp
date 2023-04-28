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

const stateSelectors = document.querySelectorAll<HTMLSelectElement>('.usa-select');
stateSelectors.forEach((stateSelector) => {
  if (!stateSelector.id.includes('jurisdiction')) {
    stateSelector.addEventListener('change', () => showOrHidePuertoRicoExtras(stateSelector.value));
    showOrHidePuertoRicoExtras(stateSelector.value);
  }
});

function onUpdateIdentityDoc() {
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
    onUpdateIdentityDoc();
  }
  if (pathname === '/verify/in_person/address') {
    onUpdateAddress();
  }
}

document.getElementById('idv_form_state')?.addEventListener('change', onStateSelectionChange);

// set initial visibility
onStateSelectionChange();

onUpdate();
