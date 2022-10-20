import sinon from 'sinon';
import { screen, waitFor } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import './modal-element';

describe('ModalElement', () => {
  function createElement() {
    document.body.innerHTML = `
      <lg-modal class="usa-modal-wrapper" hidden>
        <div role="dialog" class="usa-modal-overlay" aria-describedby="modal-description-7ace89e6" aria-labelledby="modal-label-7ace89e6">
          <div class="modal-content">
            <h2 id="modal-label-7ace89e6">
              Modal Heading
            </h2>
            Modal Content
            <button>First Button</button>
            <button data-dismiss type="button">Dismiss</button>
          </div>
        </div>
      </lg-modal>
      <button>Outside Button</button>
    `;

    return document.querySelector('lg-modal')!;
  }

  it('toggles hidden when clicking dismiss button', async () => {
    const modal = createElement();
    modal.show();
    sinon.spy(modal, 'hide');
    const dismissButton = screen.getByRole('button', { name: 'Dismiss' });
    await userEvent.click(dismissButton);

    expect(modal.hide).to.have.been.called();
  });

  describe('#show', () => {
    it('toggles visible', () => {
      const modal = createElement();
      modal.show();

      expect(modal.hasAttribute('hidden')).to.be.false();
      expect(modal.classList.contains('is-visible')).to.be.true();
      expect(document.body.classList.contains('usa-js-modal--active')).to.be.true();
    });

    it('traps focus', async () => {
      const modal = createElement();
      modal.show();

      await waitFor(() => document.activeElement?.textContent === 'First Button');
      await userEvent.tab();
      await waitFor(() => document.activeElement?.textContent === 'Dismiss');
      await userEvent.tab();
      await waitFor(() => document.activeElement?.textContent === 'First Button');
    });
  });

  describe('#hide', () => {
    it('toggles hidden', () => {
      const modal = createElement();
      modal.show();
      modal.hide();

      expect(modal.hasAttribute('hidden')).to.be.true();
      expect(modal.classList.contains('is-visible')).to.be.false();
      expect(document.body.classList.contains('usa-js-modal--active')).to.be.false();
    });

    it('releases focus trap', async () => {
      const modal = createElement();
      modal.show();
      await waitFor(() => document.activeElement?.textContent === 'First Button');
      modal.hide();

      await userEvent.tab();
      await waitFor(() => document.activeElement?.textContent === 'Outside Button');
    });
  });
});
