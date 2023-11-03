import sinon from 'sinon';
import { useRef } from 'react';
import { screen } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { renderHook } from '@testing-library/react';
import useFocusTrap from './use-focus-trap';

const delay = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('useFocusTrap', () => {
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
    const container = document.querySelector('.container') as HTMLElement;
    const { result } = renderHook(() => useFocusTrap(useRef(container), DEFAULT_OPTIONS));

    const trap = result.current!;
    expect(trap.deactivate).to.be.a('function');
  });

  it('traps focus', async () => {
    const container = document.querySelector('.container') as HTMLElement;
    renderHook(() => useFocusTrap(useRef(container), DEFAULT_OPTIONS));

    expect(container.contains(document.activeElement)).to.be.true();
    await userEvent.tab();
    expect(container.contains(document.activeElement)).to.be.true();
  });

  it('restores focus on deactivate', async () => {
    const originalActiveElement = document.activeElement;
    const container = document.querySelector('.container') as HTMLElement;
    const { result } = renderHook(() => useFocusTrap(useRef(container), DEFAULT_OPTIONS));

    const trap = result.current!;
    trap.deactivate();

    // Delay for focus return isn't configurable.
    await delay();

    expect(document.activeElement).to.equal(originalActiveElement);
  });

  it('accepts options', async () => {
    const container = document.querySelector('.container') as HTMLElement;
    const onDeactivate = sinon.spy();
    renderHook(() =>
      useFocusTrap(useRef(container), {
        ...DEFAULT_OPTIONS,
        clickOutsideDeactivates: true,
        onDeactivate,
      }),
    );

    const outsideButton = screen.getByTestId('outsideButton');

    await userEvent.click(outsideButton);
    expect(onDeactivate).to.have.been.called();
  });
});
