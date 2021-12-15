import sinon from 'sinon';
import { getByRole } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { loadPolyfills } from '@18f/identity-polyfill';
import { ClipboardButton } from './index.js';

describe('ClipboardButton', () => {
  before(async () => {
    // Necessary until: https://github.com/jsdom/jsdom/issues/1568
    await loadPolyfills(['clipboard']);

    if (!customElements.get('lg-clipboard-button')) {
      customElements.define('lg-clipboard-button', ClipboardButton);
    }
  });

  beforeEach(() => {
    sinon.spy(navigator.clipboard, 'writeText');
  });

  afterEach(() => {
    navigator.clipboard.writeText.restore();
  });

  function createAndConnectElement({ clipboardText = '' } = {}) {
    const element = document.createElement('lg-clipboard-button');
    element.setAttribute('data-clipboard-text', clipboardText);
    element.innerHTML = '<button type="button" class="usa-button">Copy</button>';
    document.body.appendChild(element);
    return element;
  }

  it('copies text to clipboard when clicking its button', () => {
    const clipboardText = 'example';
    const element = createAndConnectElement({ clipboardText });
    const button = getByRole(element, 'button');

    userEvent.click(button);

    expect(navigator.clipboard.writeText).to.have.been.calledWith(clipboardText);
  });

  it('copies the latest clipboard attribute value after initialization', () => {
    const clipboardText = 'example';
    const element = createAndConnectElement({ clipboardText });
    const changedClipbordText = 'example2';
    element.setAttribute('data-clipboard-text', changedClipbordText);

    const button = getByRole(element, 'button');

    userEvent.click(button);

    expect(navigator.clipboard.writeText).to.have.been.calledWith(changedClipbordText);
  });

  context('with nothing to copy', () => {
    it('does writes an empty string to the clipboard', () => {
      const element = createAndConnectElement();
      const button = getByRole(element, 'button');

      userEvent.click(button);

      expect(navigator.clipboard.writeText).to.have.been.calledWith('');
    });
  });
});
