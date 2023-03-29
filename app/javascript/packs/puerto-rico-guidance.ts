function showOrHidePuertoRicoGuidance(forStateCode) {
  const isPuertoRico = forStateCode === 'PR';
  const puertoRicoGuidance = document.getElementById('puerto-rico-extra-text');
  puertoRicoGuidance?.classList?.toggle('display-none', !isPuertoRico);
}

function onStateSelectionChange() {
  const stateSelector: HTMLInputElement = <HTMLInputElement>(
    document.getElementById('idv_form_state')
  );
  showOrHidePuertoRicoGuidance(stateSelector?.value);
}

document.getElementById('idv_form_state')?.addEventListener('change', onStateSelectionChange);
onStateSelectionChange(); // set initial visibility
