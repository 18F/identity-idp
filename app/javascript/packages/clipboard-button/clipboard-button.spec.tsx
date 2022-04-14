import { render } from '@testing-library/react';
import ClipboardButton from './clipboard-button';
import { ClipboardButtonElement } from './clipboard-button-element';

describe('ClipboardButton', () => {
  it('renders custom element with clipboard text data attribute', () => {
    const clipboardText = 'foo';
    const { container } = render(<ClipboardButton clipboardText={clipboardText} />);

    const element = container.firstElementChild as ClipboardButtonElement;

    expect(element.tagName).to.equal('LG-CLIPBOARD-BUTTON');
    expect(element.dataset.clipboardText).to.equal(clipboardText);
  });

  it('forwards all other props to the button child', () => {
    const { getByRole } = render(
      <ClipboardButton clipboardText="" isOutline>
        Click Me
      </ClipboardButton>,
    );

    const button = getByRole('button', { name: 'Click Me' });

    expect(button.closest('lg-clipboard-button')).to.exist();
    expect(button.classList.contains('usa-button--outline')).to.be.true();
  });
});
