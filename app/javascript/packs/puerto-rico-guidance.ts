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

document.getElementById('idv_form_state')?.addEventListener('change', onStateSelectionChange);

document.addEventListener('DOMContentLoaded', () => {
  onStateSelectionChange();
  onIdentityDocStateSelection();
});
