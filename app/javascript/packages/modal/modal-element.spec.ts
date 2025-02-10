import sinon from 'sinon';
import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { useDefineProperty } from '@18f/identity-test-helpers';
import './modal-element';

describe('ModalElement', () => {
  const defineProperty = useDefineProperty();

  let modal: HTMLElementTagNameMap['lg-modal'];

  beforeEach(() => {
    // JSDOM does not currently implement HTMLDialogElement, so stub minimal implementation
    // See: https://github.com/jsdom/jsdom/issues/3294
    defineProperty(HTMLDialogElement.prototype, 'open', {
      get() {
        return this.hasAttribute('open');
      },
    });
    defineProperty(HTMLDialogElement.prototype, 'showModal', {
      value(this: HTMLDialogElement) {
        if (this.open) {
          // "If this has an open attribute, then throw an "InvalidStateError" DOMException."
          // See: https://html.spec.whatwg.org/multipage/interactive-elements.html#dom-dialog-showmodal-dev
          throw new DOMException('InvalidStateError');
        }

        this.setAttribute('open', '');
      },
      configurable: true,
    });
    defineProperty(HTMLDialogElement.prototype, 'close', {
      value(this: HTMLDialogElement) {
        this.removeAttribute('open');
      },
      configurable: true,
    });

    document.body.innerHTML = `
      <lg-modal>
        <dialog
          class="modal__content"
          aria-describedby="modal-description-7ace89e6"
          aria-labelledby="modal-label-7ace89e6"
        >
          <h2 id="modal-label-7ace89e6">
            Modal Heading
          </h2>
          Modal Content
          <button>First Button</button>
          <button data-dismiss type="button">Dismiss</button>
        </dialog>
      </lg-modal>
      <button>Outside Button</button>
    `;

    modal = document.querySelector('lg-modal')!;
  });

  it('toggles hidden when clicking dismiss button', async () => {
    modal.show();
    sinon.spy(modal, 'hide');
    const dismissButton = screen.getByRole('button', { name: 'Dismiss' });
    await userEvent.click(dismissButton);

    expect(modal.hide).to.have.been.called();
  });

  describe('#show', () => {
    it('toggles visible', () => {
      modal.show();

      const dialog = screen.getByRole('dialog');
      expect(dialog.hasAttribute('open')).to.be.true();
      expect(document.body.classList.contains('usa-js-modal--active')).to.be.true();
    });

    context('while already visible', () => {
      it('is a noop', () => {
        modal.show();
        modal.show();

        const dialog = screen.getByRole('dialog');
        expect(dialog.hasAttribute('open')).to.be.true();
        expect(document.body.classList.contains('usa-js-modal--active')).to.be.true();
      });
    });
  });

  describe('#hide', () => {
    it('toggles hidden', () => {
      modal.show();
      modal.hide();

      const dialog = screen.getByRole('dialog', { hidden: true });
      expect(dialog.hasAttribute('open')).to.be.false();
      expect(document.body.classList.contains('usa-js-modal--active')).to.be.false();
    });
  });
});
