import { render } from '@testing-library/react';
import PromptOnNavigate from '@18f/identity-document-capture/components/prompt-on-navigate';

describe('document-capture/components/prompt-on-navigate', () => {
  it('prompts on navigate', () => {
    render(<PromptOnNavigate />);

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);

    expect(event.defaultPrevented).to.be.true();
    expect(event.returnValue).to.be.false();
  });

  it('cleans up after itself', () => {
    const { unmount } = render(<PromptOnNavigate />);
    unmount();

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);

    expect(event.defaultPrevented).to.be.false();
    expect(event.returnValue).to.be.true();
  });
});
