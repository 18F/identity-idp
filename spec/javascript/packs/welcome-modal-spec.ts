import { WELCOME_HASH, initializeWelcomeModal } from '../../../app/javascript/packs/welcome-modal';

describe('welcome-modal pack', () => {
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

    document.body.innerHTML = `
      <dialog id="welcome-modal" data-ads-modal data-ads-modal-dismissible="true"></dialog>
    `;
    window.history.replaceState(null, '', '/account');
  });

  afterEach(() => {
    window.history.replaceState(null, '', '/');
  });

  const dialog = () => document.getElementById('welcome-modal') as HTMLDialogElement;

  it('opens the modal and strips the hash when loaded at #welcome', async () => {
    window.history.replaceState(null, '', `/account${WELCOME_HASH}`);
    expect(window.location.hash).to.equal(WELCOME_HASH);

    initializeWelcomeModal();
    await Promise.resolve();

    expect(dialog().open).to.be.true();
    expect(window.location.hash).to.equal('');
    expect(window.location.pathname).to.equal('/account');
  });

  it('does not open the modal when the hash is absent', () => {
    window.history.replaceState(null, '', '/account');

    initializeWelcomeModal();

    expect(dialog().open).to.be.false();
  });

  it('preserves the hash and does not throw when the dialog is missing', () => {
    document.body.innerHTML = '';
    window.history.replaceState(null, '', `/account${WELCOME_HASH}`);

    expect(() => initializeWelcomeModal()).to.not.throw();
    expect(window.location.hash).to.equal(WELCOME_HASH);
  });
});
