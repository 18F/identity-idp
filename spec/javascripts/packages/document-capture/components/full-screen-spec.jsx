import React from 'react';
import { render, fireEvent } from '@testing-library/react';
import sinon from 'sinon';
import FullScreen from '@18f/identity-document-capture/components/full-screen';

describe('document-capture/components/full-screen', () => {
  it('renders with a close button', () => {
    const { getByLabelText } = render(<FullScreen>Content</FullScreen>);

    const button = getByLabelText('users.personal_key.close');

    expect(button.nodeName).to.equal('BUTTON');
  });

  it('is rendered as an accessible modal', () => {
    const { container } = render(<FullScreen>Content</FullScreen>);

    expect(container.firstChild.hasAttribute('aria-modal')).to.be.true();
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
    const { container } = render(<FullScreen>Content</FullScreen>);

    // The `focus-trap` library only assigns initial focus after a timeout.
    // Schedule to assert immediately following.
    setTimeout(() => {
      expect(container.contains(document.activeElement)).to.be.true();

      done();
    }, 0);
  });

  it('traps focus', (done) => {
    const { container, getByLabelText } = render(<FullScreen>Content</FullScreen>);

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

      expect(container.contains(document.activeElement)).to.be.true();

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
});
