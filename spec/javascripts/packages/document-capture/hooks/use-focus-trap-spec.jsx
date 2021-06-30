import sinon from 'sinon';
import { useRef } from 'react';
import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { renderHook } from '@testing-library/react-hooks';
import useFocusTrap from '@18f/identity-document-capture/hooks/use-focus-trap';

const delay = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('document-capture/hooks/use-focus-trap', () => {
  // Common options for test instances. Default delayed initial focus adds complexity to assertions.
  const DEFAULT_OPTIONS = { delayInitialFocus: false };

  beforeEach(() => {
    document.body.innerHTML = `
      <div class="container">
        <button data-testid="containerButton"></button>
      </div>
      <button data-testid="outsideButton"></button>
    `;
    screen.getByTestId('outsideButton').focus();
  });

  it('returns focus trap', () => {
    const container = document.querySelector('.container');
    const { result } = renderHook(() => useFocusTrap(useRef(container), DEFAULT_OPTIONS));

    const trap = result.current;
    expect(trap.deactivate).to.be.a('function');
  });

  it('traps focus', () => {
    const container = document.querySelector('.container');
    renderHook(() => useFocusTrap(useRef(container), DEFAULT_OPTIONS));

    expect(container.contains(document.activeElement)).to.be.true();
    userEvent.tab();
    expect(container.contains(document.activeElement)).to.be.true();
  });

  it('restores focus on deactivate', async () => {
    const originalActiveElement = document.activeElement;
    const container = document.querySelector('.container');
    const { result } = renderHook(() => useFocusTrap(useRef(container), DEFAULT_OPTIONS));

    const trap = result.current;
    trap.deactivate();

    // Delay for focus return isn't configurable.
    await delay();

    expect(document.activeElement).to.equal(originalActiveElement);
  });

  it('accepts options', () => {
    const container = document.querySelector('.container');
    const onDeactivate = sinon.spy();
    renderHook(() =>
      useFocusTrap(useRef(container), {
        ...DEFAULT_OPTIONS,
        clickOutsideDeactivates: true,
        onDeactivate,
      }),
    );

    const outsideButton = screen.getByTestId('outsideButton');

    userEvent.click(outsideButton);
    expect(onDeactivate).to.have.been.called();
  });
});
