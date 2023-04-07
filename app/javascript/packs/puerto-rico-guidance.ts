function showOrHidePuertoRicoExtras(forStateCode) {
  const isPuertoRico = forStateCode === 'PR';

  elements = document.getElementsByClassName('puerto-rico-extras');
  for (var i = 0; i < elements.length; ++i) {
    elements.item(i)?.classList?.toggle('display-none', !isPuertoRico);
  }
}

function onStateSelectionChange() {
  const stateSelector: HTMLInputElement = <HTMLInputElement>(
    document.getElementById('idv_form_state')
  );
  showOrHidePuertoRicoExtras(stateSelector?.value);
}

document.getElementById('idv_form_state')?.addEventListener('change', onStateSelectionChange);
onStateSelectionChange(); // set initial visibility
