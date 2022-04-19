import { render } from '@testing-library/react';
import ClipboardButton from './clipboard-button';
import ClipboardButtonElement from './clipboard-button-element';

describe('ClipboardButton', () => {
  it('renders custom element with clipboard text data attribute', () => {
    const clipboardText = 'foo';
    const { container } = render(<ClipboardButton clipboardText={clipboardText} />);

    const element = container.firstElementChild as ClipboardButtonElement;

    expect(element.tagName).to.equal('LG-CLIPBOARD-BUTTON');
    expect(element.dataset.clipboardText).to.equal(clipboardText);
    expect(element.textContent).to.equal('components.clipboard_button.label');
  });

  it('forwards all other props to the button child', () => {
    const { getByRole } = render(<ClipboardButton clipboardText="" isOutline />);

    const button = getByRole('button', { name: 'components.clipboard_button.label' });

    expect(button.closest('lg-clipboard-button')).to.exist();
    expect(button.classList.contains('usa-button--outline')).to.be.true();
  });

  it('renders with print icon', () => {
    const { getByRole } = render(<ClipboardButton clipboardText="" />);

    const icon = getByRole('img', { hidden: true });

    expect(icon.classList.contains('usa-icon')).to.be.true();
    expect(icon.querySelector('use[href$="#content_copy"]'));
  });
});
