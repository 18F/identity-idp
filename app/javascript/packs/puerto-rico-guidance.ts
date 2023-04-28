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

const updateStateSelectors = document.querySelectorAll<HTMLSelectElement>('.usa-select');
updateStateSelectors.forEach((updatedStateSelector) => {
  if (!updatedStateSelector.id.includes('jurisdiction')) {
    showOrHidePuertoRicoExtras(updatedStateSelector.value);
  }
});

document.getElementById('idv_form_state')?.addEventListener('change', onStateSelectionChange);

// set initial visibility
onStateSelectionChange();
