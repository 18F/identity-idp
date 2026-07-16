const OPEN_CLASS = 'is-open';
const CLOSING_CLASS = 'is-closing';
const BODY_LOCK_CLASS = 'ads-modal--active';
const initialized = new WeakSet<HTMLDialogElement>();

const prefersReducedMotion = () =>
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;

export const openModal = async (dialog: HTMLDialogElement) => {
  if (dialog.open) {
    if (dialog.classList.contains(OPEN_CLASS)) {
      return;
    }
    dialog.close();
  }

  dialog.classList.remove(CLOSING_CLASS, OPEN_CLASS);
  dialog.setAttribute('aria-modal', 'true');
  dialog.showModal();
  document.body.classList.add(BODY_LOCK_CLASS);

  if (prefersReducedMotion()) {
    dialog.classList.add(OPEN_CLASS);
    return;
  }

  await new Promise<void>((resolve) => {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        dialog.classList.add(OPEN_CLASS);
        resolve();
      });
    });
  });
};

export const closeModal = (dialog: HTMLDialogElement, onClose?: () => void) => {
  if (!dialog.open || dialog.classList.contains(CLOSING_CLASS)) {
    return;
  }

  const finish = () => {
    dialog.classList.remove(OPEN_CLASS, CLOSING_CLASS);
    dialog.removeAttribute('aria-modal');
    dialog.close();
    document.body.classList.remove(BODY_LOCK_CLASS);
    onClose?.();
  };

  if (prefersReducedMotion()) {
    finish();
    return;
  }

  const finishOnTransition = (event: Event) => {
    if (event.target !== dialog) {
      return;
    }

    dialog.removeEventListener('transitionend', finishOnTransition);
    finish();
  };

  dialog.addEventListener('transitionend', finishOnTransition);
  dialog.classList.remove(OPEN_CLASS);
  dialog.classList.add(CLOSING_CLASS);
};

const wireModal = ({
  modal,
  openButton,
  dismissible = true,
}: {
  modal: HTMLDialogElement;
  openButton?: Element | null;
  dismissible?: boolean;
}) => {
  const close = () => {
    if (!dismissible) {
      return;
    }
    closeModal(modal);
  };

  openButton?.addEventListener('click', async (event) => {
    event.preventDefault();
    if (openButton instanceof HTMLElement) {
      openButton.setAttribute('aria-expanded', 'true');
    }
    await openModal(modal);
  });

  modal.addEventListener('click', (event) => {
    if (event.target === modal) {
      close();
      return;
    }
    // Explicit close control always dismisses; backdrop/Esc still respect `dismissible`.
    if (event.target instanceof Element && event.target.closest('[data-ads-modal-close]')) {
      closeModal(modal);
    }
  });

  modal.addEventListener('cancel', (event) => {
    event.preventDefault();
    close();
  });

  if (openButton instanceof HTMLElement) {
    openButton.setAttribute('aria-haspopup', 'dialog');
    openButton.setAttribute('aria-controls', modal.id);
    openButton.setAttribute('aria-expanded', String(modal.open));
  }

  modal.addEventListener('close', () => {
    document.body.classList.remove(BODY_LOCK_CLASS);
    if (openButton instanceof HTMLElement) {
      openButton.setAttribute('aria-expanded', 'false');
    }
  });
};

export const setupModals = () => {
  document.querySelectorAll<HTMLDialogElement>('[data-ads-modal]').forEach((modal) => {
    if (initialized.has(modal)) {
      return;
    }

    wireModal({
      modal,
      openButton: document.querySelector(`[data-ads-modal-open][aria-controls="${modal.id}"]`),
      dismissible: modal.dataset.adsModalDismissible !== 'false',
    });
    initialized.add(modal);
  });
};

setupModals();
