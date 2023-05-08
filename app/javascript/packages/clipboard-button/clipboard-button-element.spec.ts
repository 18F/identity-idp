import sinon from 'sinon';
import { getByRole, fireEvent } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import './clipboard-button-element';

describe('ClipboardButtonElement', () => {
  const sandbox = sinon.createSandbox();

  beforeEach(() => {
    sandbox.spy(navigator.clipboard, 'writeText');
  });

  afterEach(() => {
    sandbox.restore();
  });

  function createAndConnectElement({ clipboardText = '' } = {}) {
    const element = document.createElement('lg-clipboard-button');
    element.setAttribute('clipboard-text', clipboardText);
    element.setAttribute('tooltip-text', 'Copied!');
    element.innerHTML = '<button type="button" class="usa-button">Copy</button>';
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

  it('shows a tooltip when activated, until blur', async () => {
    const element = createAndConnectElement();

    const button = getByRole(element, 'button');
    expect(computeAccessibleDescription(button)).to.be.empty();

    await userEvent.click(button);
    expect(computeAccessibleDescription(button)).to.be.equal('Copied!');

    await userEvent.tab();
    expect(computeAccessibleDescription(button)).to.be.empty();
  });

  it('shows a tooltip when activated by click without focus (Safari), until mouseout', () => {
    const element = createAndConnectElement();

    const button = getByRole(element, 'button');
    expect(computeAccessibleDescription(button)).to.be.empty();

    fireEvent.click(button);
    expect(computeAccessibleDescription(button)).to.be.equal('Copied!');

    fireEvent.mouseOut(button);
    expect(computeAccessibleDescription(button)).to.be.empty();
  });

  context('with nothing to copy', () => {
    it('does writes an empty string to the clipboard', async () => {
      const element = createAndConnectElement();
      const button = getByRole(element, 'button');

      await userEvent.click(button);

      expect(navigator.clipboard.writeText).to.have.been.calledWith('');
    });
  });
});
