import type { ModalElement } from '@18f/identity-modal';

/**
 * Token-exchange toggles on the account page. Turning a grant ON requires an
 * explicit consent step, so the toggle's form submission is intercepted and the
 * consent modal shown; confirming submits the original form. Turning a grant
 * OFF submits immediately.
 */
function init(root: HTMLElement) {
  // The modal is the only one inside this manage block in both layouts. The
  // NDS layout moves the class onto the inner <dialog>, so match the element
  // itself rather than a class on it.
  const modal = root.querySelector<ModalElement>('lg-modal');
  const targetNames = Array.from(
    modal?.querySelectorAll<HTMLElement>('[data-token-exchange-modal-target]') ?? [],
  );
  const bodies = {
    target: modal?.querySelector<HTMLElement>('[data-token-exchange-modal-body="target"]'),
    autoEnroll: modal?.querySelector<HTMLElement>('[data-token-exchange-modal-body="auto_enroll"]'),
  };
  const confirm = modal?.querySelector<HTMLButtonElement>('[data-token-exchange-modal-confirm]');

  let pending: HTMLFormElement | null = null;

  root.querySelectorAll<HTMLFormElement>('[data-token-exchange-toggle-form]').forEach((form) => {
    form.addEventListener('submit', (event) => {
      const button = form.querySelector<HTMLButtonElement>('[data-token-exchange-toggle]');
      const currentlyEnabled = button?.dataset.enabled === 'true';
      if (currentlyEnabled || !modal) {
        return; // turning OFF (or no modal available): submit directly
      }
      event.preventDefault();
      pending = form;
      const isAutoEnroll = form.dataset.grantType === 'auto_enroll';
      targetNames.forEach((el) => {
        el.textContent = form.dataset.targetName ?? '';
      });
      if (bodies.target) {
        bodies.target.hidden = isAutoEnroll;
      }
      if (bodies.autoEnroll) {
        bodies.autoEnroll.hidden = !isAutoEnroll;
      }
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

document.querySelectorAll<HTMLElement>('[data-token-exchange-manage]').forEach(init);
