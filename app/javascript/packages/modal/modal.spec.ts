import { closeModal, setupModals } from './modal';

describe('ADS modal', () => {
  beforeEach(() => {
    Object.defineProperty(window, 'matchMedia', {
      configurable: true,
      value: () => ({
        matches: true,
        addEventListener() {},
        removeEventListener() {},
      }),
    });
    Object.defineProperty(HTMLDialogElement.prototype, 'open', {
      configurable: true,
      get() {
        return this.hasAttribute('open');
      },
    });
    Object.defineProperty(HTMLDialogElement.prototype, 'showModal', {
      configurable: true,
      value(this: HTMLDialogElement) {
        this.setAttribute('open', '');
      },
    });
    Object.defineProperty(HTMLDialogElement.prototype, 'close', {
      configurable: true,
      value(this: HTMLDialogElement) {
        this.removeAttribute('open');
        this.dispatchEvent(new Event('close'));
      },
    });
  });

  const renderModal = (dismissible: boolean) => {
    document.body.innerHTML = `
      <button data-ads-modal-open aria-controls="test-modal">Open</button>
      <dialog
        id="test-modal"
        data-ads-modal
        data-ads-modal-dismissible="${dismissible}"
      >
        <button data-ads-modal-close>Close</button>
      </dialog>
    `;
    setupModals();

    return {
      dialog: document.querySelector<HTMLDialogElement>('dialog')!,
      trigger: document.querySelector<HTMLButtonElement>('[data-ads-modal-open]')!,
    };
  };

  it('lets the close control dismiss a non-dismissible modal, but not backdrop or Escape', () => {
    const { dialog, trigger } = renderModal(false);

    trigger.click();
    expect(dialog.open).to.be.true();
    expect(trigger.getAttribute('aria-expanded')).to.equal('true');

    dialog.dispatchEvent(new Event('cancel', { cancelable: true }));
    dialog.click();
    expect(dialog.open).to.be.true();

    dialog.querySelector<HTMLButtonElement>('[data-ads-modal-close]')!.click();
    expect(dialog.open).to.be.false();
  });

  it('dismisses an open modal from the backdrop', () => {
    const { dialog, trigger } = renderModal(true);

    trigger.click();
    dialog.click();

    expect(dialog.open).to.be.false();
    expect(trigger.getAttribute('aria-expanded')).to.equal('false');
  });

  it('waits for the modal transition before closing', () => {
    Object.defineProperty(window, 'matchMedia', {
      configurable: true,
      value: () => ({ matches: false }),
    });
    document.body.innerHTML = '<dialog open></dialog>';
    const dialog = document.querySelector<HTMLDialogElement>('dialog')!;

    closeModal(dialog);

    expect(dialog.open).to.be.true();
    dialog.dispatchEvent(new Event('transitionend'));
    expect(dialog.open).to.be.false();
  });
});
