import { useRef, createRef } from 'react';
import { screen } from '@testing-library/dom';
import { render, fireEvent, renderHook } from '@testing-library/react';
import sinon from 'sinon';
import FullScreen, { useInertSiblingElements } from './full-screen';
import type { FullScreenRefHandle } from './full-screen';

const delay = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('FullScreen', () => {
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

    const button = getByLabelText('account.navigation.close');

    expect(button.nodeName).to.equal('BUTTON');
  });

  context('hideCloseButton prop is true', () => {
    it('renders without a close button', () => {
      const { queryByLabelText } = render(
        <FullScreen hideCloseButton>
          <input />
        </FullScreen>,
      );

      const button = queryByLabelText('account.navigation.close');

      expect(button).to.not.exist();
    });
  });

  it('renders with white background', () => {
    const { baseElement } = render(<FullScreen>Content</FullScreen>);

    expect(baseElement.querySelector('.full-screen.bg-white')).to.exist();
  });

  context('with bgColor prop', () => {
    it('renders without a close button', () => {
      const { baseElement } = render(<FullScreen bgColor="none">Content</FullScreen>);

      expect(baseElement.querySelector('.full-screen.bg-none')).to.exist();
    });
  });

  it('applies label to dialog', () => {
    render(<FullScreen label="Modal">Content</FullScreen>);

    expect(screen.getByRole('dialog', { name: 'Modal' })).to.exist();
  });

  context('with labelledBy prop', () => {
    it('applies associates dialog with label', () => {
      render(
        <FullScreen labelledBy="custom-label">
          <span id="custom-label">Modal</span>
        </FullScreen>,
      );

      expect(screen.getByRole('dialog', { name: 'Modal' })).to.exist();
    });
  });

  context('with describedBy prop', () => {
    it('applies associates dialog with label', () => {
      render(
        <FullScreen describedBy="custom-description">
          <span id="custom-description">Description</span>
        </FullScreen>,
      );

      const dialog = screen.getByRole('dialog');

      expect(dialog.getAttribute('aria-describedby')).to.equal('custom-description');
    });
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
    const { getByRole } = render(<FullScreen>Content</FullScreen>);

    await delay(); // focus-trap delays initial focus by default
    expect(document.activeElement).to.equal(
      getByRole('button', { name: 'account.navigation.close' }),
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

    const button = getByLabelText('account.navigation.close');
    fireEvent.click(button);

    expect(onRequestClose.calledOnce).to.be.true();
  });

  it('does not call close callback when unmounted', () => {
    const onRequestClose = sinon.spy();
    const { unmount } = render(<FullScreen onRequestClose={onRequestClose}>Content</FullScreen>);

    unmount();

    expect(onRequestClose).not.to.have.been.called();
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

    const button = getByLabelText('account.navigation.close');

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

    const button = getByLabelText('account.navigation.close');

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
    const { rerender, unmount } = render(
      <>
        <FullScreen>Please don’t</FullScreen>
        <FullScreen>do this.</FullScreen>
      </>,
    );

    rerender(<FullScreen>Please don’t</FullScreen>);

    expect(document.body.classList.contains('has-full-screen-overlay')).to.be.true();

    unmount();

    expect(document.body.classList.contains('has-full-screen-overlay')).to.be.false();
  });

  it('exposes focus trap on its ref', () => {
    const ref = createRef<FullScreenRefHandle>();
    render(<FullScreen ref={ref}>Content</FullScreen>);

    expect(ref.current!.focusTrap!.deactivate).to.be.a('function');
  });
});
