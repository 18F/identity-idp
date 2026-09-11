// Expands the MFA "more options" list. Each `[data-mfa-options]` container has
// a `[data-mfa-more]` button; clicking it reveals the hidden
// `.mfa-options__item--extra` cards and moves focus to the first revealed
// control.
import { trackEvent } from '@18f/identity-analytics';

export function initialize(root: ParentNode = document) {
  root.querySelectorAll<HTMLElement>('[data-mfa-options]').forEach((container) => {
    const button = container.querySelector<HTMLButtonElement>('[data-mfa-more]');
    button?.addEventListener('click', () => {
      trackEvent('multi_factor_auth_more_options_clicked');
      container.classList.add('mfa-options--expanded');
      container.querySelector<HTMLElement>('.mfa-options__item--extra :is(button, a)')?.focus();
    });
  });
}

if (process.env.NODE_ENV !== 'test') {
  initialize();
}
