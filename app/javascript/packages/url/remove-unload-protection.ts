/**
 * Neutralizes any confirmation prompt which would otherwise occur when the user navigates to
 * another page.
 */
function removeUnloadProtection() {
  window.onbeforeunload = null;
  window.onunload = null;
}

export default removeUnloadProtection;
