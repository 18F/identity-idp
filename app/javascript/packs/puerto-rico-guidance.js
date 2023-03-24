function show_or_hide_puerto_rico_guidance(for_state_code)
{
  console.log(`show_or_hide_puerto_rico_guidance(${for_state_code})`);
  let puerto_rico_guidance = document.getElementById('puerto-rico-extra-text');
  puerto_rico_guidance.style.display = (for_state_code === 'PR' ? 'block' : 'none');
}

function on_state_selection_change()
{
  let state_selector = document.getElementById('idv_form_state');
  show_or_hide_puerto_rico_guidance(state_selector.value);
}

document.getElementById('idv_form_state').addEventListener("change", on_state_selection_change);
on_state_selection_change(); // set initial visibility
