import { getByRole } from '@testing-library/dom';
import baseUserEvent from '@testing-library/user-event';
import { useSandbox } from '@18f/identity-test-helpers';
import './clipboard-button-element';

describe('ClipboardButtonElement', () => {
  const sandbox = useSandbox({ useFakeTimers: true });
  const { clock } = sandbox;
  const userEvent = baseUserEvent.setup({ advanceTimers: clock.tick });

  beforeEach(() => {
    sandbox.spy(navigator.clipboard, 'writeText');
  });

  function createAndConnectElement({ clipboardText = '' } = {}) {
    const element = document.createElement('lg-clipboard-button');
    element.setAttribute('clipboard-text', clipboardText);
    element.setAttribute('tooltip-text', 'Copied');
    element.innerHTML = `
      <button type="button" class="ads-button ads-button--quaternary ads-button--icon-right">
        Copy
        <svg class="ads-icon" aria-hidden="true"></svg>
      </button>
      <template><svg class="ads-icon" aria-hidden="true" data-success></svg></template>
    `;
    document.body.appendChild(element);
    return element;
  }

  it('copies text to clipboard when clicking its button', async () => {
    const clipboardText = 'example';
    const element = createAndConnectElement({ clipboardText });
    const button = getByRole(element, 'button');

    await userEvent.click(button);

    expect(navigator.clipboard.writeText).to.have.been.calledWith(clipboardText);
  });

  it('copies the latest clipboard attribute value after initialization', async () => {
    const clipboardText = 'example';
    const element = createAndConnectElement({ clipboardText });
    const changedClipbordText = 'example2';
    element.setAttribute('clipboard-text', changedClipbordText);

    const button = getByRole(element, 'button');

    await userEvent.click(button);

    expect(navigator.clipboard.writeText).to.have.been.calledWith(changedClipbordText);
  });

  it('shows copied state for 1 second then reverts', async () => {
    const element = createAndConnectElement();
    const button = getByRole(element, 'button');

    await userEvent.click(button);

    expect(button.querySelector('[data-success]')).to.exist();
    expect(button.classList.contains('ads-button--secondary')).to.be.true();
    expect(element.hasAttribute('data-copied')).to.be.true();

    clock.tick(999);

    expect(button.textContent).to.include('Copied');

    clock.tick(1);

    expect(button.textContent).to.include('Copy');
    expect(button.querySelector('[data-success]')).to.not.exist();
    expect(button.classList.contains('ads-button--quaternary')).to.be.true();
    expect(element.hasAttribute('data-copied')).to.be.false();
  });

  context('with nothing to copy', () => {
    it('writes an empty string to the clipboard', async () => {
      const element = createAndConnectElement();
      const button = getByRole(element, 'button');

      await userEvent.click(button);

      expect(navigator.clipboard.writeText).to.have.been.calledWith('');
    });
  });
});
