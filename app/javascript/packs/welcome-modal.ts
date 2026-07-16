// Importing the modal package wires every in-page `[data-ads-modal]` dialog (backdrop / Esc /
// close-button dismissal) via its own module side effect, matching the sibling session packs.
import { openModal } from '@18f/identity-modal/modal';

export const WELCOME_HASH = '#welcome';
const MODAL_ID = 'welcome-modal';

/**
 * Opens the post-signup welcome modal when the page loads at `#welcome`, then strips the fragment
 * via `history.replaceState` so a refresh or back-navigation does not reopen it.
 */
export function initializeWelcomeModal() {
  if (window.location.hash !== WELCOME_HASH) {
    return;
  }

  const dialog = document.getElementById(MODAL_ID) as HTMLDialogElement | null;
  if (!dialog) {
    return;
  }

  const { pathname, search } = window.location;
  window.history.replaceState(null, '', `${pathname}${search}`);

  openModal(dialog);
}

if (process.env.NODE_ENV !== 'test') {
  initializeWelcomeModal();
}
