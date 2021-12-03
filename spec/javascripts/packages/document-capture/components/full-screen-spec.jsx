import { useRef, createRef } from 'react';
import { screen } from '@testing-library/dom';
import { render, fireEvent } from '@testing-library/react';
import { renderHook } from '@testing-library/react-hooks';
import sinon from 'sinon';
import FullScreen, {
  useInertSiblingElements,
} from '@18f/identity-document-capture/components/full-screen';

const delay = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('document-capture/components/full-screen', () => {
  describe('useInertSiblingElements', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div data-testid="sibling-1"></div>
        <div data-testid="sibling-2" aria-hidden="true"></div>
        <div data-testid="container"></div>
        <div data-testid="sibling-3"></div>
      `;
    });

    it('applies aria-hidden to siblings', () => {
      const container = screen.getByTestId('container');
      renderHook(() => useInertSiblingElements(useRef(container)));

      expect(screen.getByTestId('sibling-1').getAttribute('aria-hidden')).to.equal('true');
      expect(screen.getByTestId('sibling-2').getAttribute('aria-hidden')).to.equal('true');
      expect(screen.getByTestId('sibling-3').getAttribute('aria-hidden')).to.equal('true');
    });

    it('does not apply aria-hidden to itself', () => {
      const container = screen.getByTestId('container');
      renderHook(() => useInertSiblingElements(useRef(container)));

      expect(container.hasAttribute('aria-hidden')).to.be.false();
    });

    it('restores original hidden values to siblings after unmount', () => {
      const container = screen.getByTestId('container');
      const { unmount } = renderHook(() => useInertSiblingElements(useRef(container)));
      unmount();

      expect(screen.getByTestId('sibling-1').hasAttribute('aria-hidden')).to.be.false();
      expect(screen.getByTestId('sibling-2').getAttribute('aria-hidden')).to.equal('true');
      expect(screen.getByTestId('sibling-3').hasAttribute('aria-hidden')).to.be.false();
    });
  });

  it('renders with a close button', () => {
    const { getByLabelText } = render(<FullScreen>Content</FullScreen>);

    const button = getByLabelText('users.personal_key.close');

    expect(button.nodeName).to.equal('BUTTON');
  });

  it('focuses the first interactive element', async () => {
    const { getByRole } = render(
      <FullScreen>
        <button type="button">One</button>
        <button type="button">Two</button>
      </FullScreen>,
    );

    await delay(); // focus-trap delays initial focus by default
    expect(document.activeElement).to.equal(getByRole('button', { name: 'One' }));
  });

  it('focuses the close button as a fallback', async () => {
    const { getByRole } = render(<FullScreen />);

    await delay(); // focus-trap delays initial focus by default
    expect(document.activeElement).to.equal(
      getByRole('button', { name: 'users.personal_key.close' }),
    );
  });

  it('is rendered as an accessible modal', () => {
    const { getByRole } = render(<FullScreen>Content</FullScreen>);

    expect(getByRole('dialog')).to.be.ok();
  });

  it('calls close callback when close button is clicked', () => {
    const onRequestClose = sinon.spy();
    const { getByLabelText } = render(
      <FullScreen onRequestClose={onRequestClose}>Content</FullScreen>,
    );

    const button = getByLabelText('users.personal_key.close');
    fireEvent.click(button);

    expect(onRequestClose.calledOnce).to.be.true();
  });

  it('transitions focus into the modal', (done) => {
    const { baseElement } = render(<FullScreen>Content</FullScreen>);

    // The `focus-trap` library only assigns initial focus after a timeout.
    // Schedule to assert immediately following.
    setTimeout(() => {
      expect(baseElement.contains(document.activeElement)).to.be.true();

      done();
    }, 0);
  });

  it('traps focus', (done) => {
    const { baseElement, getByLabelText } = render(<FullScreen>Content</FullScreen>);

    const button = getByLabelText('users.personal_key.close');

    const event = new window.KeyboardEvent('keydown', {
      key: 'Tab',
      code: 'Tab',
      which: 9,
    });

    // The `focus-trap` library only assigns initial focus after a timeout.
    // Schedule to assert immediately following.
    setTimeout(() => {
      fireEvent(button, event);

      expect(baseElement.contains(document.activeElement)).to.be.true();

      done();
    }, 0);
  });

  it('closes on escape press', () => {
    const onRequestClose = sinon.spy();
    const { getByLabelText, rerender } = render(<FullScreen>Content</FullScreen>);
    rerender(<FullScreen onRequestClose={onRequestClose}>Content</FullScreen>);

    const button = getByLabelText('users.personal_key.close');

    const event = new window.KeyboardEvent('keydown', {
      key: 'Escape',
      code: 'Escape',
      which: 27,
    });

    fireEvent(button, event);

    expect(onRequestClose.calledOnce).to.be.true();
  });

  it('toggles modal class on body while mounted', () => {
    const { unmount } = render(<FullScreen>Content</FullScreen>);

    expect(document.body.classList.contains('has-full-screen-overlay')).to.be.true();

    unmount();

    expect(document.body.classList.contains('has-full-screen-overlay')).to.be.false();
  });

  it('only removes body class when last mounted modal is removed', () => {
    const { rerender } = render(
      <>
        <FullScreen>Please don’t</FullScreen>
        <FullScreen>do this.</FullScreen>
      </>,
    );

    rerender(<FullScreen>Please don’t</FullScreen>);

    expect(document.body.classList.contains('has-full-screen-overlay')).to.be.true();

    rerender(null);

    expect(document.body.classList.contains('has-full-screen-overlay')).to.be.false();
  });

  it('exposes focus trap on its ref', () => {
    const ref = createRef();
    render(<FullScreen ref={ref}>Content</FullScreen>);

    expect(ref.current.focusTrap.deactivate).to.be.a('function');
  });
});
