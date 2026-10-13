import type { ModalElement } from '@18f/identity-modal';

/**
 * Delegated-access toggles on the account page. Turning an application ON is an approval, so the
 * toggle's form submission is intercepted and the confirmation modal shown; confirming submits
 * the original form. Turning an application OFF submits immediately.
 */
function init(root: HTMLElement) {
  // The modal is the only one inside this block in both layouts. The NDS layout moves the class
  // onto the inner <dialog>, so match the element itself rather than a class on it.
  const modal = root.querySelector<ModalElement>('lg-modal');
  const applicationNames = Array.from(
    modal?.querySelectorAll<HTMLElement>('[data-delegation-modal-application]') ?? [],
  );
  const confirm = modal?.querySelector<HTMLButtonElement>('[data-delegation-modal-confirm]');

  let pending: HTMLFormElement | null = null;

  root.querySelectorAll<HTMLFormElement>('[data-delegation-toggle-form]').forEach((form) => {
    form.addEventListener('submit', (event) => {
      const button = form.querySelector<HTMLButtonElement>('[data-delegation-toggle]');
      const currentlyEnabled = button?.dataset.enabled === 'true';
      if (currentlyEnabled || !modal) {
        return; // turning OFF (or no modal available): submit directly
      }
      event.preventDefault();
      pending = form;
      applicationNames.forEach((el) => {
        el.textContent = form.dataset.applicationName ?? '';
      });
      modal.show();
    });
  });

  confirm?.addEventListener('click', () => {
    const form = pending;
    pending = null;
    modal?.hide();
    form?.submit();
  });
}

document.querySelectorAll<HTMLElement>('[data-delegation-manage]').forEach(init);
