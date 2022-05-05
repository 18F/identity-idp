import { waitFor } from '@testing-library/dom';
import { useSandbox } from '@18f/identity-test-helpers';
import BaseModal from '../../../../app/javascript/app/components/modal';

describe('components/modal', () => {
  const sandbox = useSandbox();

  class Modal extends BaseModal {
    static instances = [];

    constructor(...args) {
      super(...args);
      Modal.instances.push(this);
    }
  }

  function createModalContainer(id = 'modal') {
    const container = document.createElement('div');
    container.id = id;
    container.className = 'modal display-none';
    container.innerHTML = `
      <div class="usa-modal-wrapper is-visible">
        <div class="usa-modal-overlay">
          <div class="padding-x-2 padding-y-6 modal" role="dialog">
            <div class="modal-center">
              <div class="modal-content">
                <p>Do action?</p>
                <button type="button">Yes</button>
                <button type="button">No</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    `;

    return container;
  }

  beforeEach(() => {
    document.body.appendChild(createModalContainer());
  });

  afterEach(() => {
    Modal.instances.forEach((instance) => {
      instance.off();
      if (instance.shown) {
        instance.hide();
      }
    });
  });

  it('shows with initial focus', async () => {
    const onShow = sandbox.stub();
    const modal = new Modal({ el: '#modal' });
    modal.on('show', onShow);
    modal.show();

    await waitFor(() => expect(document.activeElement.nodeName).to.equal('BUTTON'));
    expect(onShow.called).to.be.true();
    expect(document.activeElement.textContent).to.equal('Yes');
    const container = document.activeElement.closest('#modal');
    expect(container.classList.contains('display-none')).to.be.false();
    expect(document.body.classList.contains('usa-js-modal--active')).to.be.true();
  });

  it('allows interaction in most recently activated focus trap', async () => {
    document.body.appendChild(createModalContainer('modal2'));
    const modal = new Modal({ el: '#modal' });
    const modal2 = new Modal({ el: '#modal2' });

    modal.show();

    await waitFor(() => expect(document.activeElement.closest('#modal')).to.be.ok());

    modal2.show();

    await waitFor(() => expect(document.activeElement.closest('#modal2')).to.be.ok());

    await new Promise((resolve) => {
      document.activeElement.addEventListener('click', (event) => {
        if (!event.defaultPrevented) {
          resolve();
        }
      });

      document.activeElement.click();
    });
  });
});
