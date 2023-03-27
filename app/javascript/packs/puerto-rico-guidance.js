function showOrHidePuertoRicoGuidance(forStateCode)
{
  let puertoRicoGuidance = document.getElementById('puerto-rico-extra-text');
  if (forStateCode === 'PR') {
    puertoRicoGuidance.classList.remove('display-none');
    puertoRicoGuidance.classList.add('display-block');
  }
  else {
    puertoRicoGuidance.classList.remove('display-block');
    puertoRicoGuidance.classList.add('display-none');
  }
}

function onStateSelectionChange()
{
  let stateSelector = document.getElementById('idv_form_state');
  showOrHidePuertoRicoGuidance(stateSelector.value);
}

document.getElementById('idv_form_state').addEventListener("change", onStateSelectionChange);
onStateSelectionChange(); // set initial visibility
